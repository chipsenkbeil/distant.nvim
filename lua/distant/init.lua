local Cli            = require('distant-core').Cli
local Destination    = require('distant-core').Destination
local EventEmitter   = require('distant-core').EventEmitter
local installer      = require('distant-core').installer
local log            = require('distant-core').log
local Manager        = require('distant-core').Manager
local utils          = require('distant-core').utils
local Version        = require('distant-core').Version

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

--- Contains defaults used by the plugin.
local DEFAULT        = require('distant.default')

--- Represents the minimum version of the CLI supported by this plugin.
local MIN_VERSION    = Version:parse('0.20.0')

--- Represents the version of the plugin (not CLI).
local PLUGIN_VERSION = Version:parse('0.3.0')

--- @class distant.plugin.Version
--- @field cli {min:distant.core.Version}
--- @field plugin distant.core.Version
local VERSION        = {
    --- Version information related to the CLI used by this plugin
    cli = {
        --- Minimum version of the CLI the plugin supports
        min = MIN_VERSION,
    },
    --- Version of the plugin itself
    plugin = PLUGIN_VERSION,
}

-------------------------------------------------------------------------------
-- DISTANT PLUGIN DEFINITION
-------------------------------------------------------------------------------

--- Distant is a plugin that enables working with remote machines from the
--- comfort of your local editor, neovim! This Lua wrapper around the `distant`
--- CLI provides extensions to both utilize neovim buffers to edit remote files
--- and navigate the filesystem while also providing utilities to execute
--- commands on the remote machines.
---
--- The plugin enables a variety of vim commands that you can use to work on
--- remote machines while also standing up an extensive user interface to make
--- working with remote machines easier than ever.
---
--- If you wish to programmatically work with remote machines using the distant
--- API, this plugin entrypoint is for you!
---
--- @class distant.Plugin
--- @field api distant.plugin.Api # plugin API for working remotely
--- @field buf distant.plugin.Buffer # plugin buffer interface for working with buffer data
--- @field editor distant.plugin.Editor # interface to working with the editor
--- @field settings distant.plugin.Settings # plugin user-defined settings
--- @field version distant.plugin.Version # plugin version information
---
--- @field private __initialized boolean|'in-progress' # true if initialized
--- @field private __client_id? distant.core.manager.ConnectionId # id of the active client
--- @field private __manager? distant.core.Manager # active manager
local M              = {}
M.__index            = M

--- Creates a new instance of this plugin.
---
--- If provided an `instance`, will update it to be a plugin.
---
--- @param opts? {instance?:table}
--- @return distant.Plugin
function M:new(opts)
    opts = opts or {}
    local instance = opts.instance or {}
    setmetatable(instance, M)

    instance.api      = require('distant.api')
    instance.buf      = require('distant.buffer')
    instance.editor   = require('distant.editor')
    instance.settings = vim.deepcopy(DEFAULT.SETTINGS)
    instance.version  = vim.deepcopy(VERSION)

    return instance
end

-------------------------------------------------------------------------------
-- EVENT API
-------------------------------------------------------------------------------

local EVENT_EMITTER = EventEmitter:new()

--- @alias distant.events.Event
--- | '"connection:changed"' # when the plugin switches the active connection
--- | '"manager:started"' # when the manager was not running and was started by the plugin
--- | '"manager:loaded"' # when the manager is loaded for the first time
--- | '"settings:changed"' # when the stateful settings are changed
--- | '"setup:finished"' # when setup of the plugin has finished

--- Emits the specified event to trigger all associated handlers
--- and passes all additional arguments to the handler.
---
--- @param event distant.events.Event # event to emit
--- @param ... any # additional arguments to get passed to handlers
--- @return distant.Plugin
function M:emit(event, ...)
    log.fmt_trace('distant:emit(%s, %s)', event, { ... })
    EVENT_EMITTER:emit(event, ...)
    return self
end

--- Registers a callback to be invoked when the specified event is emitted.
--- More than one handler can be associated with the same event.
---
--- @param event distant.events.Event # event to receive
--- @param handler fun(payload:any) # callback to trigger on event
--- @return distant.Plugin
function M:on(event, handler)
    log.fmt_trace('distant:on(%s, %s)', event, handler)
    EVENT_EMITTER:on(event, handler)
    return self
end

--- Registers a callback to be invoked when the specified event is emitted.
--- Upon being triggered, the handler will be removed.
---
--- More than one handler can be associated with the same event.
---
--- @param event distant.events.Event # event to receive
--- @param handler fun(payload:any) # callback to trigger on event
--- @return distant.Plugin
function M:once(event, handler)
    log.fmt_trace('distant:once(%s, %s)', event, handler)
    EVENT_EMITTER:once(event, handler)
    return self
end

--- Unregisters the callback for the specified event.
---
--- @param event distant.events.Event # event whose handler to remove
--- @param handler fun(payload:any) # handler to remove
--- @return distant.Plugin
function M:off(event, handler)
    log.fmt_trace('distant:off(%s, %s)', event, handler)
    EVENT_EMITTER:off(event, handler)
    return self
end

-------------------------------------------------------------------------------
-- MANAGEMENT API
-------------------------------------------------------------------------------

--- @class distant.plugin.LoadManagerOpts
--- @field reload? boolean # if true, will reload the manager even if already defined
--- @field bin? string
--- @field network? {private?:boolean, unix_socket?:string, windows_pipe?:string}
--- @field log_file? string
--- @field log_level? distant.core.log.Level
--- @field timeout? number
--- @field interval? number

--- Loads the manager using the specified config, installing the underlying cli
--- if necessary. Will utilize the user-defined settings as defaults for
--- things like CLI bin path, network settings, and more.
---
--- If `cb` is provided, this function runs asynchronously and invokes the
--- callback once finished or an error is encountered. Otherwise, the function
--- runs synchronously and returns once finished or an error is encountered.
---
--- @param opts distant.plugin.LoadManagerOpts
--- @param cb? fun(err?:string, manager?:distant.core.Manager)
--- @return string|nil err, distant.core.Manager|nil manager
function M:load_manager(opts, cb)
    opts = opts or {}

    -- Update our opts with default setting values if not overwritten
    local timeout = opts.timeout or self.settings.network.timeout.max
    local interval = opts.interval or self.settings.network.timeout.interval
    local log_file = opts.log_file or self.settings.manager.log_file
    local log_level = opts.log_level or self.settings.manager.log_level

    local rx
    if not cb then
        cb, rx = utils.oneshot_channel(timeout, interval)
    end

    if not self.__manager or opts.reload then
        self:cli({ path = opts.bin }):install({ min_version = self.version.cli.min }, function(err, path)
            if err then
                return cb(err)
            end

            -- Define our manager now
            self.__manager = self:__setup_manager({ binary = path })

            local is_listening = self.__manager:is_listening({
                timeout = timeout,
                interval = interval,
            })
            if not is_listening then
                log.debug('Manager not listening, so starting process')

                --- @diagnostic disable-next-line:redefined-local
                self.__manager:listen({
                    daemon = self.settings.manager.daemon,
                    log_file = log_file,
                    log_level = log_level,
                    user = self.settings.manager.user,
                }, function(err)
                    if err then
                        log.fmt_error('Manager failed: %s', err)
                    else
                        -- Emit that the manager was successfully started
                        self:emit('manager:started', self.__manager)
                    end
                end)

                if not self.__manager:wait_for_listening({}) then
                    log.error('Manager still does not appear to be listening')
                end
            end

            -- Emit that the manager was successfully loaded, which only happens
            -- once as we don't count subsequent calls to this method
            self:emit('manager:loaded', self.__manager)

            return cb(nil, self.__manager)
        end)
    else
        cb(nil, self.__manager)
    end

    -- If we have a receiver, this indicates that we are synchronous
    if rx then
        --- @type boolean, string|nil, distant.core.Manager|nil
        local _, err, manager = pcall(rx)
        return err, manager
    end
end

--- @class distant.plugin.LaunchOpts
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
--- @param opts distant.plugin.LaunchOpts
--- @param cb fun(err?:string, client?:distant.core.Client)
function M:launch(opts, cb)
    self:__assert_initialized()

    -- Retrieve the destination and put it in a structured format
    local destination = opts.destination
    assert(destination, 'Destination is missing')
    if type(destination) == 'string' then
        destination = Destination:parse(destination)
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
        local settings = self:server_settings_for_host(destination.host)

        -- Augment our destination with defaults
        destination.scheme = destination.scheme or settings.launch.default.scheme
        destination.port = destination.port or settings.launch.default.port
        destination.username = destination.username or settings.launch.default.username

        --- @diagnostic disable-next-line:redefined-local
        manager:launch({
            destination         = destination:as_string(),
            -- User-defined settings
            cache               = opts.cache,
            config              = opts.config,
            distant             = opts.distant or settings.launch.default.bin,
            distant_bind_server = opts.distant_bind_server,
            distant_args        = opts.distant_args or settings.launch.default.args,
            log_file            = opts.log_file,
            log_level           = opts.log_level,
            network             = opts.network,
            options             = opts.options or settings.launch.default.options,
        }, function(err, client)
            if client then
                self:set_active_client_id(client)
            end

            return cb(err, client)
        end)
    end)
end

--- @class distant.plugin.ConnectOpts
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
--- @param opts distant.plugin.ConnectOpts
--- @param cb fun(err?:string, client?:distant.core.Client)
function M:connect(opts, cb)
    self:__assert_initialized()

    local destination = opts.destination
    assert(destination, 'Destination is missing')
    if type(destination) == 'string' then
        destination = Destination:parse(destination)
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
        local settings = self:server_settings_for_host(destination.host)

        -- Augment our destination with defaults
        destination.scheme = destination.scheme or settings.connect.default.scheme
        destination.port = destination.port or settings.connect.default.port
        destination.username = destination.username or settings.connect.default.username

        --- @diagnostic disable-next-line:redefined-local
        manager:connect({
            --- @cast destination string
            destination = destination,
            -- User-defined settings
            cache       = opts.cache,
            config      = opts.config,
            log_file    = opts.log_file,
            log_level   = opts.log_level,
            options     = opts.options or settings.connect.default.options,
        }, function(err, client)
            if client then
                self:set_active_client_id(client)
            end

            return cb(err, client)
        end)
    end)
end

--- @class distant.plugin.ConnectionsOpts
--- @field bin? string # path to local cli binary to use to facilitate launch
--- @field network? distant.core.manager.Network
--- @field config? string #alternative config path to use
--- @field cache? string #alternative cache path to use
--- @field log_file? string #alternative log file path to use
--- @field log_level? distant.core.log.Level #alternative log level to use
--- @field timeout? number
--- @field interval? number

--- Retrieves a list of connections being actively managed.
--- @param opts distant.plugin.ConnectionsOpts
--- @param cb? fun(err?:string, connections?:distant.core.manager.ConnectionMap)
--- @return string|nil err, distant.core.manager.ConnectionMap|nil connections
function M:connections(opts, cb)
    self:__assert_initialized()

    local rx
    if not cb then
        cb, rx = utils.oneshot_channel(
            opts.timeout or self.settings.network.timeout.max,
            opts.interval or self.settings.network.timeout.interval
        )
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

        manager:list({
            refresh   = true,
            -- User-defined settings
            cache     = opts.cache,
            config    = opts.config,
            log_file  = opts.log_file,
            log_level = opts.log_level,
        }, cb)
    end)

    if rx then
        --- @type boolean, string|nil, distant.core.manager.ConnectionMap|nil
        local _, err, connections = pcall(rx)
        return err, connections
    end
end

-------------------------------------------------------------------------------
-- SETTINGS API
-------------------------------------------------------------------------------

--- Retrieves server settings for a specific client by looking up the server
--- settings based on the host pointed to by the client.
---
--- If `id` is not provided, the active client will be used instead.
---
--- @param id? distant.core.manager.ConnectionId|distant.core.Client
--- @return distant.plugin.settings.ServerSettings
function M:server_settings_for_client(id)
    log.fmt_trace('distant:server_settings_for_client(%s)', vim.inspect(id))
    self:__assert_initialized()

    -- If given a client, use its id
    if type(id) == 'table' then
        id = id.id
    end

    --- @cast id distant.core.manager.ConnectionId|nil
    id = id or self.__client_id

    local host
    if id then
        local destination = self.__manager:connection_destination(id)
        if destination then
            host = destination.host
        end
    end

    return self:server_settings_for_host(host or '*')
end

--- Retrieves server settings for a particular host, merging them with the
--- default settings specified by '*'.
---
--- If the host is not found, the default settings will be used in entirety.
---
--- @param host string
--- @return distant.plugin.settings.ServerSettings
function M:server_settings_for_host(host)
    log.fmt_trace('distant:server_settings_for_host(%s)', vim.inspect(host))
    self:__assert_initialized()

    local default_settings = self.settings.servers['*'] or {}

    -- Short circuit if we were told to retrieve default settings
    if host == '*' then
        return default_settings
    end

    -- Otherwise, merge specifics with defaults, keeping the specifics
    return vim.tbl_deep_extend(
        'keep',
        self.settings.servers[host] or {},
        default_settings
    )
end

-------------------------------------------------------------------------------
-- SETUP API
-------------------------------------------------------------------------------

--- Returns whether or not this plugin is initialized.
---
--- Initialization should only happen once as part of calling setup for the plugin.
---
--- @return boolean
function M:is_initialized()
    return self.__initialized == true
end

--- Asserts that the plugin is initialized, throwing an error if uninitialized.
--- @private
function M:__assert_initialized()
    if self.__initialized == 'in-progress' then
        error(table.concat({
            'Distant plugin is currently initializing!',
            'Please wait until it is finished.'
        }, ' '))
    elseif not self:is_initialized() then
        assert(self:is_initialized(), table.concat({
            'Distant plugin has not yet been initialized!',
            'Please call distant:setup() prior to using the plugin!',
        }), ' ')
    end
end

--- Applies provided settings to overall settings available. By default, this runs asynchronously.
---
--- When given a root-level key with dots, they will be expanded into a nested table. For instance,
--- providing `"buffer.watch.enabled" = true` will get expanded into `{buffer = {watch = {enabled = true}}}`.
---
--- ### Options
---
--- * `verbatim` - if true, will not modify the settings in any way.
--- * `wait` - if provided, will wait up to the specified maximum milliseconds for the setup to complete.
---
--- @param settings distant.plugin.Settings
--- @param opts? {verbatim?:boolean, wait?:integer}
function M:setup(settings, opts)
    -- Ensure something is populated
    opts = opts or {}
    settings = settings or {}
    log.fmt_trace('distant:setup(settings = %s, opts = %s)', settings, opts)

    -- Check if using the old distant.setup versus distant:setup
    if getmetatable(self) ~= M then
        log.error(table.concat({
            'It seems like you may be using the old setup process!',
            'You now need to invoke setup using a colon instead of a dot.',
            '',
            'Change require(\'distant\').setup to require(\'distant\'):setup',
        }, '\n'))
        return
    end

    if self:is_initialized() then
        log.warn(table.concat({
            'distant:setup() called more than once!',
            'Ignoring new call to setup.'
        }, ' '))
        return
    end

    -- Detect if old setup is being used by checking for a '*' field
    if settings['*'] ~= nil then
        log.warn(table.concat({
            'It seems like you may be using the old setup process!',
            'Server settings have now moved to the `servers` field.',
            '',
            'Support for server settings at the top level is deprecated!',
            'Please update your configuration.',
        }, '\n'))

        -- Move our server settings to the appropriate location
        settings = {
            servers = settings,
        }
    end

    -- Transform root settings keys with dots into nested tables
    if opts.verbatim ~= true then
        for key, value in pairs(settings) do
            if type(key) == 'string' then
                local tokens = vim.split(key, '.', { plain = true })

                -- If we have more than one token, this means there was a dot
                if #tokens > 1 then
                    -- Clear the setting so we can expand it
                    settings[key] = nil

                    --- @type table<string, any>
                    local tbl = settings
                    for idx, token in ipairs(tokens) do
                        local is_last = idx == #tokens

                        -- If we have reached the last part of the path,
                        -- set it as a key=value in our table
                        --
                        -- Otherwise, continue iterating
                        if is_last then
                            tbl[token] = value
                        else
                            -- If we don't have anything at this point,
                            -- provide an empty table to fill in
                            if tbl[token] == nil then
                                tbl[token] = {}
                            end

                            -- If we don't have a table as our value,
                            -- this is an error and we should fail
                            if type(tbl[token]) ~= 'table' then
                                error(
                                    'Cannot overwrite non-table value in path: ' ..
                                    table.concat(tokens, '.', 1, idx)
                                )
                            end

                            -- Otherwise, update our settings to point
                            -- to the nested table so we can continue
                            --- @type table<string, any>
                            tbl = tbl[token]
                        end
                    end
                end
            end
        end
    end

    -- Ensure that we are properly initialized with user-provided settings
    self:__setup(settings)

    -- If we were told to setup the plugin synchronously, block until ready
    if type(opts.wait) == 'number' then
        --- @type integer
        local timeout = opts.wait

        assert(
            vim.wait(timeout, function() return self:is_initialized() end),
            string.format(
                'Timeout of %.2fs reached waiting for distant:setup() to complete',
                timeout
            )
        )
    end
end

--- Initialize the plugin. Invoked during setup process after user-defined
--- settings have been merged into the plugin.
---
--- Does the following:
---
--- * Populate plugin's private fields
--- * Initialize autocommands
--- * Initialize vim commands
--- * Initialize user interface
--- * Provide sane defaults for settings
--- * Merge in user-defined settings
---
--- @private
--- @param settings distant.plugin.Settings # user-defined settings
function M:__setup(settings)
    log.trace('distant:__setup()')
    if self.__initialized == true or self.__initialized == 'in-progress' then
        return
    end

    local function finished()
        -- Mark as initialized to prevent performing this again
        log.debug('distant:setup:done')
        self.__initialized = true

        -- Notify listeners that our setup has finished
        self:emit('setup:finished')
    end

    log.debug('distant:setup:start')
    self.__initialized = 'in-progress'

    --------------------------------------------------------------------------
    -- INITIALIZE CORE EDITOR FEATURES
    --------------------------------------------------------------------------

    -- Ensure our autocmds are initialized
    log.debug('distant:setup:autocmd')
    require('distant.autocmd').initialize()

    -- Ensure our commands are initialized
    log.debug('distant:setup:commands')
    require('distant.commands').initialize()

    -- Ensure our user interface is initialized
    log.debug('distant:setup:ui')
    require('distant.ui').initialize()

    --------------------------------------------------------------------------
    -- POPULATE SETTINGS
    --------------------------------------------------------------------------

    -- Update our global settings by merging with the provided settings
    log.debug('distant:setup:settings')
    self.settings = vim.tbl_deep_extend('force', self.settings, settings)

    --------------------------------------------------------------------------
    -- MANAGER INITIALIZATION
    --------------------------------------------------------------------------

    -- If we are not lazy, attempt to load the manager immediately
    if not self.settings.manager.lazy then
        log.debug('distant:setup:manager')

        -- We spawn this async knowing that it should be quick
        -- and we don't want to block if the CLI needs to be
        -- installed as we'd get a timeout error in most situations
        self:load_manager({}, function(err, _)
            assert(not err, err)
            finished()
        end)
    else
        log.debug('distant:setup:manager:lazy')
        finished()
    end
end

--- Creates a new manager based on user-defined settings.
--- @param opts? {binary?:string}
--- @return distant.core.Manager
function M:__setup_manager(opts)
    opts = opts or {}

    -- Whether or not to create a private network
    local private = self.settings.network.private

    --- @type distant.core.manager.Network
    local network = {
        windows_pipe = self.settings.network.windows_pipe,
        unix_socket = self.settings.network.unix_socket,
    }
    if private then
        --- Create a private network if `private` is true, which means a network limited
        --- to this specific neovim instance. Any pre-existing defined windows pipe
        --- and unix socket will persist and not be overwritten
        network = vim.tbl_extend('keep', network, {
            windows_pipe = 'nvim-' .. utils.next_id(),
            unix_socket = utils.cache_path('nvim-' .. utils.next_id() .. '.sock'),
        })
    end

    local manager_opts = {
        binary = opts.binary or self:cli().path,
        network = network,
    }
    return Manager:new(manager_opts)
end

-------------------------------------------------------------------------------
-- SHELL API
-------------------------------------------------------------------------------

--- Spawns a shell connected to the buffer with handle `bufnr`.
---
--- * `bufnr` specifies the buffer to use. If -1, will create a new buffer. Default is -1.
--- * `winnr` specifies the window to use. Default is current window.
--- * `cmd` is the optional command to use instead of the server's default shell.
--- * `cwd` is the optional current working directory to set for the shell when spawning it.
--- * `env` is the optional map of environment variable values to supply to the shell.
---
--- Will fail with an error if the shell fails to spawn.
---
--- @param opts {bufnr?:number, winnr?:number, cmd?:string|string[], cwd?:string, env?:table<string, string>}
--- @return number bufnr
function M:spawn_shell(opts)
    opts = opts or {}

    -- If not specified, set buffer to be created
    if type(opts.bufnr) ~= 'number' then
        opts.bufnr = -1
    end

    log.fmt_debug('Spawning shell %s', opts)
    local client = assert(self:client(), 'No client established')
    local _, bufnr = client:spawn_shell(opts)
    self.buf(bufnr).set_client_id(client.id)

    log.fmt_debug('Shell spawned into buffer %s', bufnr)
    return bufnr
end

-------------------------------------------------------------------------------
-- UTILITIES API
-------------------------------------------------------------------------------

--- Retrieves the client with the specified `id`, or the active client if no
--- id is specified.
---
--- Note: This does NOT refresh the list of clients being managed by the
--- manager process. This is merely a means to construct a Lua wrapper around
--- a client using a connection id.
---
--- @param id? distant.core.manager.ConnectionId # optional client id, if not provided uses the active id
--- @return distant.core.Client|nil # client if exists, otherwise nil
function M:client(id)
    self:__assert_initialized()

    local connection = id or self.__client_id
    if connection then
        return self.__manager:client(connection)
    end
end

--- Returns the destination of the client with the specified `id`, or the
--- active client's destination if no id is specified.
---
--- Note: This does NOT refresh the list of clients being managed by the
--- manager process.
---
--- @param id? distant.core.manager.ConnectionId # optional client id, if not provided uses the active id
--- @return distant.core.Destination|nil # client destination if exists, otherwise nil
function M:client_destination(id)
    self:__assert_initialized()

    local connection = id or self.__client_id
    if connection then
        return self.__manager:connection_destination(connection)
    end
end

--- Returns the id of the active client.
--- @return distant.core.manager.ConnectionId|nil
function M:active_client_id()
    return self.__client_id
end

--- Sets the active client to be specified `id`.
---
--- Note: This does NOT refresh the list of clients being managed by the
--- manager process. This is merely a means to construct a Lua wrapper around
--- a client using a connection id.
---
--- @param id distant.core.manager.ConnectionId|distant.core.Client
function M:set_active_client_id(id)
    self:__assert_initialized()

    -- If given a client, retrieve its id
    if type(id) == 'table' then
        id = id.id
    end

    -- If given a string, convert it to a number
    if type(id) == 'string' then
        id = assert(tonumber(id), 'id must be a 32-bit unsigned integer')
    end

    --- @cast id distant.core.manager.ConnectionId
    self.__client_id = id

    self:emit(
        'connection:changed',
        assert(self:client(id), 'Invalid client id for active client')
    )
end

--- Returns a reference to the manager tied to this plugin. Will be nil
--- until the manager is initialized.
---
--- @return distant.core.Manager|nil
function M:manager()
    self:__assert_initialized()
    return self.__manager
end

--- Returns a reference to the manager tied to this plugin.
--- Will fail if manager is not initialized.
---
--- @return distant.core.Manager
function M:assert_manager()
    return assert(self:manager(), 'Manager is not initialized')
end

--- Returns a CLI pointing to the appropriate binary.
---
--- If no `path` is provided, the path defined in plugin settings will be used.
---
--- If that path is not executable and the path was not changed from the default
--- value, the path managed by the installer will be used instead.
---
--- @param opts? {path?:string}
--- @return distant.core.Cli
function M:cli(opts)
    opts = opts or {}

    -- Use the provided path, or default to the settings path
    --
    -- If the settings path is a default value, then we fall
    -- back to the installer path if the default is not executable
    local path = opts.path
    if not path then
        path = self.settings.client.bin
        local is_default = path == 'distant' or path == 'distant.exe'
        if not Cli:new({ path = path }):is_executable() and is_default then
            path = installer.path()
        end
    end

    return Cli:new({ path = path })
end

-------------------------------------------------------------------------------
-- WRAP API
-------------------------------------------------------------------------------


--- @class distant.plugin.SpawnWrapOpts
--- @field client_id? distant.core.manager.ConnectionId # if provided, will wrap using the specified client
--- @field cmd? string|string[] # wraps a regular command
--- @field cwd? string # specifies the current working directory
--- @field env? table<string,string> # specifies environment variables for the spawned process
--- @field shell? string|string[]|true # used to define that the process should be spawned in a shell

--- Performs a client wrapping of the given `cmd`, `lsp`, or `shell` parameter.
---
--- If both `cmd` and `shell` are provided, then `spawn` is invoked with
--- the command and `shell` is used as the `--shell <shell>` parameter.
---
--- If `client_id` is provided, will wrap using the given client; otherwise,
--- will use the active client. Will fail if the client is not available.
---
--- Returns a job representing the spawned process.
---
--- @param opts distant.plugin.SpawnWrapOpts
--- @param cb? fun(err?:string, exit_status:distant.core.job.ExitStatus)
--- @return distant.core.Job
function M:spawn_wrap(opts, cb)
    log.fmt_trace('distant:spawn_wrap(%s)', opts)
    self:__assert_initialized()

    local client = assert(
        self:client(opts.client_id),
        'Client unavailable for spawning wrapped cmd'
    )

    return client:spawn_wrap({
        cmd = opts.cmd,
        cwd = opts.cwd,
        env = opts.env,
        shell = opts.shell,
    }, cb)
end

--- @class distant.plugin.WrapOpts
--- @field client_id? distant.core.manager.ConnectionId # if provided, will wrap using the specified client
--- @field cmd? string|string[] # wraps a regular command
--- @field lsp? string|string[] # wraps an LSP server command
--- @field shell? string|string[]|true # wraps a shell, taking an optional shell command (or --shell if using `cmd`)
--- @field cwd? string # specifies the current working directory
--- @field env? table<string,string> # specifies environment variables for the spawned process
--- @field scheme? string # if provided, uses this scheme instead of the default (lsp only)

--- Performs a client wrapping of the given `cmd`, `lsp`, or `shell` parameter.
---
--- If both `cmd` and `shell` are provided, then `spawn` is invoked with
--- the command and `shell` is used as the `--shell <shell>` parameter.
---
--- If `client_id` is provided, will wrap using the given client; otherwise,
--- will use the active client. Will fail if the client is not available.
---
--- Returns a string if the input is a string, or a list if the input is a list.
---
--- @param opts distant.plugin.WrapOpts
--- @return string|string[]
function M:wrap(opts)
    log.fmt_trace('distant:wrap(%s)', opts)
    self:__assert_initialized()

    local client = assert(
        self:client(opts.client_id),
        'Client unavailable for wrapping'
    )

    -- Construct the prefix we want to remove
    -- when wrapping an LSP server
    local prefix = M.buf.name.prefix({
        scheme = 'distant',
        connection = self:active_client_id(),
    })

    return client:wrap({
        cmd = opts.cmd,
        lsp = opts.lsp,
        shell = opts.shell,
        cwd = opts.cwd,
        env = opts.env,
        scheme = prefix,
    })
end

-------------------------------------------------------------------------------
-- PLUGIN CREATION
-------------------------------------------------------------------------------

--- This is a lazily-configured version of our plugin. To avoid a cyclical
--- dependencies and slow startup, we avoid configuring our plugin until
--- first access.
---
--- @type distant.Plugin
local PLUGIN = {}

--- The metatable we set for our plugin will lazy-load it when access is
--- detected. When lazy-loading, we remove this metatable and inject our actual
--- plugin instead.
setmetatable(PLUGIN, {
    --- Lazily convert object into our plugin upon access.
    __index = function(tbl, key)
        -- Clear the old metatable of our plugin to not be lazy
        setmetatable(tbl, nil)

        -- Update our plugin
        M:new({ instance = tbl })

        return tbl[key]
    end
})

return PLUGIN
