local Cli         = require('distant-core').Cli
local Destination = require('distant-core').Destination
local events      = require('distant.events')
local installer   = require('distant-core').installer
local log         = require('distant-core').log
local Manager     = require('distant-core').Manager
local min_version = require('distant.version').minimum
local settings    = require('distant-core').settings
local utils       = require('distant-core').utils

--- @class distant.State
--- @field client? distant.core.Client #active client
--- @field manager? distant.core.Manager #active manager
--- @field active_search {qfid?:number, searcher?:distant.api.Searcher} #active search via editor
--- @field settings distant.core.Settings #user settings
local M           = {}
M.__index         = M

--- @return distant.State
function M:new()
    local instance = {}
    setmetatable(instance, M)
    instance.client = nil
    instance.manager = nil
    instance.active_search = {}

    -- Set default settings so we don't get nil access errors even when no
    -- launch call has been made yet
    instance.settings = settings.default()

    return instance
end

--- Loads into state the settings appropriate for the remote machine with the give label
--- @param destination string Full destination to server, which can be in a form like SCHEME://USER:PASSWORD@HOST:PORT
--- @return distant.core.Settings
function M:load_settings(destination)
    log.fmt_trace('Detecting settings for destination: %s', destination)

    -- Parse our destination into the host only
    local label
    local d = Destination:try_parse(destination)
    if not d or not d.host then
        error('Invalid destination: ' .. tostring(destination))
    else
        label = d.host
        log.fmt_debug('Using settings label: %s', label)
    end

    self.settings = settings.for_label(label)
    log.fmt_debug('Settings loaded: %s', self.settings)

    -- Emit that the settings have changed and provide a copy
    -- of the settings (copy to avoid them being changed)
    events.emit_settings_changed(vim.deepcopy(self.settings))

    return self.settings
end

--- Returns the path to the distant CLI binary.
--- @param opts? {no_install_fallback?:boolean}
--- @return string
function M:path_to_cli(opts)
    opts = opts or {}

    local no_install_fallback = opts.no_install_fallback or false

    -- If we are not given a custom bin path, the settings bin path
    -- hasn't changed (from distant/distant.exe), and the current
    -- bin path isn't executable, then check if the install path
    -- exists and is executable and use it
    local bin = self.settings.client.bin
    local is_bin_generic = bin == 'distant' or bin == 'distant.exe'
    if not no_install_fallback and is_bin_generic and vim.fn.executable(bin) ~= 1 then
        bin = installer.path()
    end

    return bin
end

--- @class distant.state.LoadManagerOpts
--- @field bin? string
--- @field network? {private?:boolean, unix_socket?:string, windows_pipe?:string}
--- @field log_file? string
--- @field log_level? distant.core.log.Level
--- @field timeout? number
--- @field interval? number

--- Loads the manager using the specified config, installing the underlying cli if necessary.
--- @param opts distant.state.LoadManagerOpts
--- @param cb? fun(err?:string, manager?:distant.core.Manager)
--- @return string|nil err, distant.core.Manager|nil manager
function M:load_manager(opts, cb)
    -- If we are not given a custom bin path, the settings bin path
    -- hasn't changed (from distant/distant.exe), and the current
    -- bin path isn't executable, then check if the install path
    -- exists and is executable and use it
    local bin = opts.bin or self:path_to_cli()

    -- Update our opts with default setting values if not overwritten
    local timeout = opts.timeout or self.settings.max_timeout
    local interval = opts.interval or self.settings.timeout_interval
    local log_file = opts.log_file or self.settings.manager.log_file
    local log_level = opts.log_level or self.settings.manager.log_level

    local rx
    if not cb then
        cb, rx = utils.oneshot_channel(timeout, interval)
    end

    if not self.manager then
        Cli:new({ bin = bin }):install({ min_version = min_version }, function(err, path)
            if err then
                return cb(err)
            end

            -- Whether or not to create a private network
            -- TODO: This does not work right now! The settings are loaded AFTER
            --       the manager begins to listen as a connection has to happen to load
            --       the settings. We need to revamp how settings work so we have
            --       network settings separate from server settings!
            local private = opts.network and opts.network.private or self.settings.network.private

            --- @type distant.core.manager.Network
            local network = opts.network or {}
            if private then
                --- Create a private network if `private` is true, which means a network limited
                --- to this specific neovim instance. Any pre-existing defined windows pipe
                --- and unix socket will persist and not be overwritten
                network = vim.tbl_extend('keep', network, {
                    windows_pipe = 'nvim-' .. utils.next_id(),
                    unix_socket = utils.cache_path('nvim-' .. utils.next_id() .. '.sock'),
                })
            end

            local manager_opts = { binary = path, network = network }
            log.fmt_debug('Defining manager configuration as %s', manager_opts)
            self.manager = Manager:new(manager_opts)

            local is_listening = self.manager:is_listening({
                timeout = timeout,
                interval = interval,
            })
            if not is_listening then
                log.debug('Manager not listening, so starting process')

                --- @diagnostic disable-next-line:redefined-local
                self.manager:listen({
                    log_file = log_file,
                    log_level = log_level,
                }, function(err)
                    if err then
                        log.fmt_error('Manager failed: %s', err)
                    else
                        -- Emit that the manager was successfully started
                        events.emit_manager_started(self.manager)
                    end
                end)

                if not self.manager:wait_for_listening({}) then
                    log.error('Manager still does not appear to be listening')
                end
            end

            -- Emit that the manager was successfully loaded, which only happens
            -- once as we don't count subsequent calls to this method
            events.emit_manager_loaded(self.manager)

            return cb(nil, self.manager)
        end)
    else
        cb(nil, self.manager)
    end

    -- If we have a receiver, this indicates that we are synchronous
    if rx then
        --- @type boolean, string|nil, distant.core.Manager|nil
        local _, err, manager = pcall(rx)
        return err, manager
    end
end

--- @class distant.core.state.LaunchOpts
--- @field destination string|distant.core.Destination
--- @field bin? string # path to local cli binary to use to facilitate launch
--- @field network? distant.core.manager.Network
--- @field config? string #alternative config path to use
--- @field cache? string #alternative cache path to use
--- @field distant? string #alternative path to distant binary (on remote machine) to use
--- @field distant_bind_server? 'any'|'ssh'|string #control the IP address that the server binds to
--- @field distant_args? string|string[] #additional arguments to supply to distant binary on remote machine
--- @field log_file? string #alternative log file path to use
--- @field log_level? distant.core.log.Level #alternative log level to use
--- @field options? string|table<string, any> #additional options tied to a specific destination handler
--- @field timeout? number
--- @field interval? number

--- Launches a remote server and connects to it.
--- @param opts distant.core.state.LaunchOpts
--- @param cb fun(err?:string, client?:distant.core.Client)
function M:launch(opts, cb)
    local destination = opts.destination
    assert(destination, 'Destination is missing')
    if type(destination) == 'table' then
        destination = destination:as_string()
    end

    self:load_manager({
        bin = opts.bin,
        network = opts.network,
        timeout = opts.timeout,
        interval = opts.interval,
    }, function(err, manager)
        if err then
            return cb(err)
        end

        assert(manager, 'Impossible: manager is nil')

        --- @diagnostic disable-next-line:redefined-local
        manager:launch({
            --- @cast destination string
            destination         = destination,
            -- User-defined settings
            cache               = opts.cache,
            config              = opts.config,
            distant             = opts.distant,
            distant_bind_server = opts.distant_bind_server,
            distant_args        = opts.distant_args,
            log_file            = opts.log_file,
            log_level           = opts.log_level,
            network             = opts.network,
            options             = opts.options,
        }, function(err, client)
            if client then
                self.client = client

                -- Emit that the connection (client) was successfully changed
                events.emit_connection_changed(self.client)
            end

            return cb(err, client)
        end)
    end)
end

--- @class distant.core.state.ConnectOpts
--- @field destination string|distant.core.Destination
--- @field bin? string # path to local cli binary to use to facilitate launch
--- @field network? distant.core.manager.Network
--- @field config? string #alternative config path to use
--- @field cache? string #alternative cache path to use
--- @field log_file? string #alternative log file path to use
--- @field log_level? distant.core.log.Level #alternative log level to use
--- @field options? string|table<string, any> #additional options tied to a specific destination handler
--- @field timeout? number
--- @field interval? number

--- Connects to a remote server.
--- @param opts distant.core.state.ConnectOpts
--- @param cb fun(err?:string, client?:distant.core.Client)
function M:connect(opts, cb)
    local destination = opts.destination
    assert(destination, 'Destination is missing')
    if type(destination) == 'table' then
        destination = destination:as_string()
    end

    self:load_manager({
        bin      = opts.bin,
        network  = opts.network,
        timeout  = opts.timeout,
        interval = opts.interval,
    }, function(err, manager)
        if err then
            return cb(err)
        end

        assert(manager, 'Impossible: manager is nil')

        --- @diagnostic disable-next-line:redefined-local
        manager:connect({
            --- @cast destination string
            destination = destination,
            -- User-defined settings
            cache       = opts.cache,
            config      = opts.config,
            log_file    = opts.log_file,
            log_level   = opts.log_level,
            options     = opts.options,
        }, function(err, client)
            if client then
                self.client = client

                -- Emit that the connection (client) was successfully changed
                events.emit_connection_changed(self.client)
            end

            return cb(err, client)
        end)
    end)
end

--- @class distant.core.state.ConnectionsOpts
--- @field bin? string # path to local cli binary to use to facilitate launch
--- @field network? distant.core.manager.Network
--- @field config? string #alternative config path to use
--- @field cache? string #alternative cache path to use
--- @field log_file? string #alternative log file path to use
--- @field log_level? distant.core.log.Level #alternative log level to use
--- @field timeout? number
--- @field interval? number

--- Returns a list of connections being managed.
--- @param opts distant.core.state.ConnectionsOpts
--- @param cb fun(err?:string, connections?:table<string, distant.core.Destination>)
function M:connections(opts, cb)
    self:load_manager({
        bin      = opts.bin,
        network  = opts.network,
        timeout  = opts.timeout,
        interval = opts.interval,
    }, function(err, manager)
        if err then
            return cb(err)
        end

        assert(manager, 'Impossible: manager is nil')

        manager:list({
            -- User-defined settings
            cache     = opts.cache,
            config    = opts.config,
            log_file  = opts.log_file,
            log_level = opts.log_level,
        }, cb)
    end)
end

--- @class distant.core.state.SelectOpts
--- @field connection string # connection to select
--- @field bin? string # path to local cli binary to use to facilitate launch
--- @field network? distant.core.manager.Network
--- @field cache? string #alternative cache path to use
--- @field config? string #alternative config path to use
--- @field log_file? string #alternative log file path to use
--- @field log_level? distant.core.log.Level #alternative log level to use
--- @field timeout? number
--- @field interval? number

--- Selects a connection, which includes changing the active client and
--- reloading settings according to the host.
---
--- @param opts distant.core.state.SelectOpts
--- @param cb fun(err?:string, client?:distant.core.Client)
function M:select(opts, cb)
    local connection = opts.connection

    -- Load our manager and refresh the connections
    -- before attempting to assign the client
    self:connections({
        bin       = opts.bin,
        cache     = opts.cache,
        config    = opts.config,
        log_file  = opts.log_file,
        log_level = opts.log_level,
        network   = opts.network,
        timeout   = opts.timeout,
        interval  = opts.interval,
    }, function(err, _)
        if err then
            cb(err)
            return
        end

        -- Manager should exist if we're loading connections
        local manager = assert(self.manager)

        self.client = assert(
            manager:client(connection),
            'Neovim manager lost track of client'
        )

        -- Should exist if the client above exists
        local destination = assert(manager:connection_destination(connection))

        -- Reload our settings based on the destination
        self:load_settings(destination:as_string())

        -- Report the change
        events.emit_connection_changed(self.client)

        cb(nil, self.client)
    end)
end

local GLOBAL_STATE = M:new()
return GLOBAL_STATE
