--- Settings tied to the distant plugin.
--- @class distant.plugin.Settings
local DEFAULT_SETTINGS = {
    --- Buffer-specific settings that are applied to buffers this plugin controls.
    --- @class distnat.plugin.settings.BufferSettings
    buffer = {
        --- Settings that apply to watching a buffer for remote changes.
        --- @class distnat.plugin.settings.buffer.WatchSettings
        watch = {
            --- If true, will watch buffers for changes.
            --- @type boolean
            enabled = true,
            --- Time in milliseconds between attempts to retry a watch request for a buffer
            --- when the path represented by the buffer does not exist. Set to 0 to disable.
            --- @type integer
            retry_timeout = 5000,
        },
    },
    --- Client-specific settings that are applied when this plugin controls the client.
    --- @class distant.plugin.settings.ClientSettings
    client = {
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
    --- @alias distant.plugin.settings.Keymap
    --- | string # single key combination
    --- | string[] # multiple key combinations (any of these)
    ---
    --- Collection of key mappings across the plugin.
    --- @class distant.plugin.settings.KeymapSettings
    keymap = {
        --- Mappings that apply when editing a remote directory.
        --- @class distant.plugin.settings.keymap.DirSettings
        dir = {
            --- If true, will apply keybindings when the buffer is created.
            --- @type boolean
            enabled = true,
            --- Keymap to copy the file or directory under the cursor.
            --- @type distant.plugin.settings.Keymap
            copy = 'C',
            --- Keymap to edit the file or directory under the cursor.
            --- @type distant.plugin.settings.Keymap
            edit = '<Return>',
            --- Keymap to display metadata for the file or directory under the cursor.
            --- @type distant.plugin.settings.Keymap
            metadata = 'M',
            --- Keymap to create a new directory within the open directory.
            --- @type distant.plugin.settings.Keymap
            newdir = 'K',
            --- Keymap to create a new file within the open directory.
            --- @type distant.plugin.settings.Keymap
            newfile = 'N',
            --- Keymap to rename the file or directory under the cursor.
            --- @type distant.plugin.settings.Keymap
            rename = 'R',
            --- Keymap to remove the file or directory under the cursor.
            --- @type distant.plugin.settings.Keymap
            remove = 'D',
            --- Keymap to navigate up into the parent directory.
            --- @type distant.plugin.settings.Keymap
            up = '-',
        },
        --- Mappings that apply when editing a remote file.
        --- @class distant.plugin.settings.keymap.FileSettings
        file = {
            --- If true, will apply keybindings when the buffer is created.
            --- @type boolean
            enabled = true,
            --- Keymap to navigate up into the parent directory.
            --- @type distant.plugin.settings.Keymap
            up = '-',
        },
        --- Mappings that apply to distant's user interface.
        --- @class distant.plugin.settings.keymap.UserInterfaceSettings
        ui = {
            --- Used to exit the window.
            --- @type distant.plugin.settings.Keymap
            exit = { 'q', '<Esc>' },
            --- Mappings that apply to the main window.
            main = {
                --- Mappings for the connections tab.
                connections = {
                    --- Kill the connection under cursor.
                    --- @type distant.plugin.settings.Keymap
                    kill = 'K',
                    --- Toggle information about the server/connection under cursor.
                    --- @type distant.plugin.settings.Keymap
                    toggle_info = 'I',
                },
                --- General mappings for tabs.
                tabs = {
                    --- Used to bring up the connections tab.
                    --- @type distant.plugin.settings.Keymap
                    goto_connections = '1',
                    --- Used to bring up the system info tab.
                    --- @type distant.plugin.settings.Keymap
                    goto_system_info = '2',
                    --- Used to bring up the help menu.
                    --- @type distant.plugin.settings.Keymap
                    goto_help = '?',
                    --- Used to refresh data in a tab.
                    --- @type distant.plugin.settings.Keymap
                    refresh = 'R',
                }
            },
        },
    },
    --- Manager-specific settings that are applied when this plugin controls the manager.
    --- @class distant.plugin.settings.ManagerSettings
    manager = {
        --- If true, when neovim starts a manager, it will be run as a daemon, which
        --- will detach it from the neovim process. This means that the manager will
        --- persist after neovim itself exits.
        --- @type boolean
        daemon = false,
        --- If true, will avoid starting the manager until first needed. (default: true)
        --- @type boolean
        lazy = true,
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
        --- @class distant.plugin.settings.network.Timeout
        timeout = {
            --- Maximimum time to wait (in milliseconds) for requests to finish
            --- @type integer
            max = 15 * 1000,
            --- Time to wait (in milliseconds) inbetween checks to see if a request timed out
            --- @type integer
            interval = 256,
        },
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

            --- If specified, will apply the current working directory to any cases of spawning processes,
            --- opening directories & files, starting shells, and wrapping commands.
            ---
            --- Will be overwritten if an explicit `cwd` or absolute path is provided in those situations.
            --- @type string|nil
            cwd = nil,

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
}

return {
    SETTINGS = DEFAULT_SETTINGS
}
