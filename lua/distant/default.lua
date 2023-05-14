--- Settings tied to the distant plugin.
--- @class distant.plugin.Settings
local DEFAULT_SETTINGS = {
    --- Client-specific settings that are applied when this plugin controls the client.
    --- @class distant.plugin.settings.ClientSettings
    client = {
        --- If true, will allow unstable versions of the CLI to be installed.
        --- @type boolean
        allow_unstable = false,
        --- Binary to use locally with the client.
        ---
        --- Defaults to "distant" on Unix platforms and "distant.exe" on Windows.
        ---
        --- @type string
        bin = (function()
            local os_name = require('distant-core').utils.detect_os_arch()
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
        --- If true, when neovim starts a manager, it will be run as a daemon, which
        --- will detach it from the neovim process. This means that the manager will
        --- persist after neovim itself exits.
        --- @type boolean
        daemon = false,
        --- If true, will avoid starting the manager until first needed.
        --- @type boolean
        lazy = false,
        --- @type string|nil
        log_file = nil,
        --- @type distant.core.log.Level|nil
        log_level = nil,
        --- If true, when neovim starts a manager, it will listen on a user-local
        --- domain socket or windows pipe rather than the globally-accessible variant.
        --- @type boolean
        user = false,
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

            --- Settings that apply when connecting to a server on a remote machine
            --- @class distant.plugin.settings.server.ConnectSettings
            connect = {
                --- @class distant.plugin.settings.server.connect.DefaultSettings
                --- @field scheme? string # scheme to use in place of letting distant infer an appropriate scheme (e.g. 'ssh')
                --- @field port? integer # port to use when connecting
                --- @field username? string # username when connecting to the server (defaults to user running neovim)
                --- @field options? string # options to pass along to distant when connecting (e.g. ssh backend)
                default = {},
            },

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
            launch = {
                --- @class distant.plugin.settings.server.launch.DefaultSettings
                --- @field scheme? string # scheme to use in place of letting distant infer an appropriate scheme (e.g. 'ssh')
                --- @field port? integer # port to use when launching (not same as what server listens on)
                --- @field username? string # username when accessing machine to launch server (defaults to user running neovim)
                ---
                --- @field bin? string # path to distant binary on remote machine
                --- @field args? string[] # additional CLI arguments for binary upon launch
                --- @field options? string # options to pass along to distant when launching (e.g. ssh backend)
                default = {},
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

return {
    settings = DEFAULT_SETTINGS
}
