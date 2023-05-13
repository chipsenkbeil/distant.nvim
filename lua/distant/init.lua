local Cli            = require('distant-core').Cli
local EventEmitter   = require('distant-core').EventEmitter
local installer      = require('distant-core').installer
local log            = require('distant-core').log
local Manager        = require('distant-core').Manager
local utils          = require('distant-core').utils
local Version        = require('distant-core').Version

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

--- Represents the minimum version of the CLI supported by this plugin.
local MIN_VERSION    = Version:parse('0.20.0-alpha.5')

--- Represents the version of the plugin (not CLI).
local PLUGIN_VERSION = Version:parse('0.2.0-alpha.1')

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
--- @field fn distant.plugin.Fn # plugin API for working remotely
--- @field settings distant.plugin.Settings # plugin user-defined settings
--- @field version distant.plugin.Version # plugin version information
---
--- @field private __initialized boolean|'in-progress' # true if initialized
--- @field private __client_id? string # id of the active client
--- @field private __manager? distant.core.Manager # active manager
local M              = {}
M.__index            = M

-------------------------------------------------------------------------------
-- EVENT API
-------------------------------------------------------------------------------

local EVENT_EMITTER  = EventEmitter:new()

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
    self:__assert_initialized()

    -- Update our opts with default setting values if not overwritten
    local timeout = opts.timeout or self.settings.timeout.max
    local interval = opts.interval or self.settings.timeout.interval
    local log_file = opts.log_file or self.settings.manager.log_file
    local log_level = opts.log_level or self.settings.manager.log_level

    local rx
    if not cb then
        cb, rx = utils.oneshot_channel(timeout, interval)
    end

    if not self.__manager or opts.reload then
        self:cli(opts):install({ min_version = self.version.cli.min }, function(err, path)
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
                    log_file = log_file,
                    log_level = log_level,
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
                -- Update our active client to this one and store it in our tracker
                self.__client_id = client:connection()

                -- Emit that the connection (client) was successfully changed
                self:emit('connection:changed', client)
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
                -- Update our active client to this one and store it in our tracker
                self.__client_id = client:connection()

                -- Emit that the connection (client) was successfully changed
                self:emit('connection:changed', client)
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
--- @param cb? fun(err?:string, connections?:table<string, distant.core.Destination>)
--- @return string|nil err, table<string, distant.core.Destination>|nil connections
function M:connections(opts, cb)
    self:__assert_initialized()

    local rx
    if not cb then
        cb, rx = utils.oneshot_channel(
            opts.timeout or self.settings.timeout.max,
            opts.interval or self.settings.timeout.interval
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
        --- @type boolean, string|nil, table<string, distant.core.Destination>|nil
        local _, err, connections = pcall(rx)
        return err, connections
    end
end

-------------------------------------------------------------------------------
-- SETTINGS API
-------------------------------------------------------------------------------

--- Settings tied to the distant plugin.
--- @class distant.plugin.Settings
M.settings = {
    --- Client-specific settings that are applied when this plugin controls the client.
    --- @class distant.plugin.settings.ClientSettings
    client = {
        --- Binary to use locally with the client.
        ---
        --- Defaults to "distant" on Unix platforms and "distant.exe" on Windows.
        ---
        --- @type string
        bin = (function()
            local os_name = utils.detect_os_arch()
            return os_name == 'windows' and 'distant.exe' or 'distant'
        end)(),

        --- @type string|nil
        log_file = nil,

        --- @type distant.core.log.Level|nil
        log_level = nil,
    },

    --- Manager-specific settings that are applied when this plugin controls the manager.
    --- @class distant.plugin.settings.ManagerSettings
    manager = {
        --- If true, will avoid starting the manager until first needed.
        --- @type boolean
        lazy = false,

        --- @type string|nil
        log_file = nil,

        --- @type distant.core.log.Level|nil
        log_level = nil,
    },

    --- Network configuration to use between the manager and clients.
    --- @class distant.plugin.settings.Network
    network = {
        --- If true, will create a private network for all operations
        --- associated with a singular neovim instance
        --- @type boolean
        private = false,

        --- If provided, will overwrite the pipe name used for network
        --- communication on Windows machines
        --- @type string|nil
        windows_pipe = nil,

        --- If provided, will overwrite the unix socket path used for network
        --- communication on Unix machines
        --- @type string|nil
        unix_socket = nil,
    },

    --- Collection of settings for servers defined by their hostname.
    ---
    --- A key of "\*" is special in that it is considered the default for
    --- all servers and will be applied first with any host-specific
    --- settings overwriting the default.
    ---
    --- @type table<string, distant.plugin.settings.ServerSettings>
    servers = {
        --- Default server settings
        --- @class distant.plugin.settings.ServerSettings
        ['*'] = {
            --- Settings that apply to the navigation interface
            --- @class distant.plugin.settings.server.DirSettings
            dir = {
                --- Mappings to apply to the navigation interface
                --- @type table<string, fun()>
                mappings = {},
            },

            --- Settings that apply when editing a remote file
            --- @class distant.plugin.settings.server.FileSettings
            file = {
                --- Mappings to apply to remote files
                --- @type table<string, fun()>
                mappings = {},
            },

            --- Settings that apply when launching a server on a remote machine
            --- @class distant.plugin.settings.server.LaunchSettings
            --- @field bin? string # path to distant binary on remote machine
            --- @field args? string[] # additional CLI arguments for binary upon launch
            launch = {
                args = { '--shutdown', 'lonely=60' },
            },

            --- @alias distant.plugin.settings.server.lsp.RootDirFn fun(path:string):string|nil
            --- @class distant.plugin.settings.server.lsp.ServerSettings
            --- @field cmd string|string[]
            --- @field root_dir string|string[]|distant.plugin.settings.server.lsp.RootDirFn
            --- @field filetypes? string[]
            --- @field on_exit? fun(code:number, signal?:number, client_id:string)

            --- Settings to use to start LSP instances. Mapping of a label
            --- to the settings for that specific LSP server
            --- @alias distant.plugin.settings.server.LspSettings table<string, distant.plugin.settings.server.lsp.ServerSettings>
            --- @type distant.plugin.settings.server.LspSettings
            lsp = {},
        },
    },

    --- @class distant.plugin.settings.Timeout
    timeout = {
        --- Maximimum time to wait (in milliseconds) for requests to finish
        --- @type integer
        max = 15 * 1000,

        --- Time to wait (in milliseconds) inbetween checks to see if a request timed out
        --- @type integer
        interval = 256,
    },
}

--- Retrieves server settings for a specific client by looking up the server
--- settings based on the host pointed to by the client.
---
--- If `id` is not provided, the active client will be used instead.
---
--- @param id? string|distant.core.Client
--- @return distant.plugin.settings.ServerSettings|nil
function M:server_settings_for_client(id)
    log.fmt_trace('distant:server_settings_for_client(%s)', id)
    self:__assert_initialized()

    -- If given a client, retrieve its connection as the id
    if type(id) == 'table' then
        id = id:connection()
    end

    --- @cast id string?
    id = id or self.__client_id

    if id then
        local destination = self.__manager:connection_destination(id)
        if destination then
            return self.settings.servers[destination.host]
        end
    end
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

--- Applies provided settings to overall settings available.
--- @param settings distant.plugin.Settings
function M:setup(settings)
    log.fmt_trace('distant:setup(%s)', settings)
    if self:is_initialized() then
        log.warn(table.concat({
            'distant:setup() called more than once!',
            'Ignoring new call to setup.'
        }, ' '))
        return
    end

    -- Ensure something is populated
    settings = settings or {}

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

    -- Ensure that we are properly initialized with user-provided settings
    self:__setup(settings)
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

    -- Populate our settings with some defaults (avoiding require cyclical loop)
    log.debug('distant:setup:settings:defaults')
    local nav = require('distant.nav')
    self.settings.servers['*'].dir.mappings = {
        ['<Return>'] = nav.actions.edit,
        ['-']        = nav.actions.up,
        ['K']        = nav.actions.mkdir,
        ['N']        = nav.actions.newfile,
        ['R']        = nav.actions.rename,
        ['D']        = nav.actions.remove,
    }
    self.settings.servers['*'].file.mappings = {
        ['-'] = nav.actions.up,
    }

    -- Update our global settings by merging with the provided settings
    log.debug('distant:setup:settings:user')
    self.settings = vim.tbl_deep_extend('force', self.settings, settings)

    --------------------------------------------------------------------------
    -- UPDATE PLUGIN WITH LAZY POPULATION
    --------------------------------------------------------------------------

    -- We do this to avoid a cyclical dependency during requiring
    log.debug('distant:setup:fn')
    self.fn = require('distant.fn')

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
        binary = opts.binary or self:path_to_cli(),
        network = network,
    }
    return Manager:new(manager_opts)
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
--- @param id? string # optional client id, if not provided uses the active id
--- @return distant.core.Client|nil # client if exists, otherwise nil
function M:client(id)
    self:__assert_initialized()

    local connection = id or self.__client_id
    if connection then
        return self.__manager:client(connection)
    end
end

--- Sets the active client to be specified `id`.
---
--- Note: This does NOT refresh the list of clients being managed by the
--- manager process. This is merely a means to construct a Lua wrapper around
--- a client using a connection id.
---
--- @param id string|distant.core.Client
function M:set_active_client(id)
    self:__assert_initialized()

    -- If given a client, retrieve its connection as the id
    if type(id) == 'table' then
        id = id:connection()
    end

    --- @cast id string
    self.__client_id = id
end

--- Returns a reference to the manager tied to this plugin.
--- @return distant.core.Manager
function M:manager()
    self:__assert_initialized()
    return self.__manager
end

--- Returns a CLI pointing to the appropriate binary.
--- @param opts? {bin?:string}
--- @return distant.core.Cli
function M:cli(opts)
    opts = opts or {}
    local bin = opts.bin or self:path_to_cli()
    return Cli:new({ bin = bin })
end

--- Returns the path to the distant CLI binary, first trying the user-defined
--- settings and falling back to the installer path if the user-defined path
--- is not executable.
---
--- * If `no_install_fallback` is true, the installer path will not be tried when
---   the user-defined path is not executable.
--- * If `require_executable` is true, an error will be thrown if the selected
---   path is not executable.
---
--- @param opts? {no_install_fallback?:boolean, require_executable?:boolean}
--- @return string
function M:path_to_cli(opts)
    log.fmt_trace('distant:path_to_cli(%s)', opts)
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

    if opts.require_executable and vim.fn.executable(bin) ~= 1 then
        error('distant is not available on path')
    end

    return bin
end

-------------------------------------------------------------------------------
-- VERSION API
-------------------------------------------------------------------------------

--- @class distant.plugin.Version
--- @field cli {min:distant.core.Version}
--- @field plugin distant.core.Version
M.version = {
    --- Version information related to the CLI used by this plugin
    cli = {
        --- Minimum version of the CLI the plugin supports
        min = MIN_VERSION,
    },

    --- Version of the plugin itself
    plugin = PLUGIN_VERSION,
}

-------------------------------------------------------------------------------
-- WRAP API
-------------------------------------------------------------------------------

--- @class distant.plugin.WrapOpts
--- @field client_id? string # if provided, will wrap using the specified client
--- @field cmd? string|string[] # wraps a regular command
--- @field lsp? string|string[] # wraps an LSP server command
--- @field shell? string|string[]|true # wraps a shell, taking an optional shell command
--- @field cwd? string # specifies the current working directory
--- @field env? table<string,string> # specifies environment variables for the spawned process

--- Performs a client wrapping of the given `cmd`, `lsp`, or `shell` parameter.
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

    return client:wrap({
        cmd = opts.cmd,
        lsp = opts.lsp,
        shell = opts.shell,
        cwd = opts.cwd,
        env = opts.env,
    })
end

return M
