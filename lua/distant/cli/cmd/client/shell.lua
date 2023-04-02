local BaseCmd = require('distant.cli.cmd.base')

--- @class ClientShellCmd: BaseCmd
--- @field __cmd string
local ClientShellCmd = BaseCmd:new('client shell', {
    allowed = {
        'config',
        'cache',
        'connection',
        'current-dir',
        'environment',
        'log-file',
        'log-level',
        'persist',
        'pty',
        'unix-socket',
        'windows-pipe',

    }
})

--- Creates new shell cmd
--- @param prog? string #optional prog to run instead of $TERM
--- @return ClientShellCmd
function ClientShellCmd:new(prog)
    self.__internal = {}
    self.__prog = prog
    return self
end

--- Returns cmd as a list
--- @return string[]
function ClientShellCmd:as_list()
    local lst = BaseCmd.as_list(self)
    if self.__prog then
        table.insert(lst, '--')
        table.insert(lst, self.__prog)
    end
    return lst
end

--- Sets `--config <path>`
--- @param path string
--- @return ClientShellCmd
function ClientShellCmd:set_config(path)
    vim.validate({ path = { path, 'string' } })
    return self:set('config', path)
end

--- Sets `--cache <path>`
--- @param path string
--- @return ClientShellCmd
function ClientShellCmd:set_cache(path)
    vim.validate({ path = { path, 'string' } })
    return self:set('cache', path)
end

--- Sets `--connection <id>`
--- @param id string
--- @return ClientShellCmd
function ClientShellCmd:set_connection(id)
    vim.validate({ id = { id, 'string' } })
    return self:set('connection', id)
end

--- Sets `--current-dir <dir>`
--- @param dir string
--- @return ClientShellCmd
function ClientShellCmd:set_current_dir(dir)
    vim.validate({ dir = { dir, 'string' } })
    return self:set('current-dir', dir)
end

--- Sets `--environment <id>`
--- @param environment table<string, string>
--- @return ClientShellCmd
function ClientShellCmd:set_environment(environment)
    vim.validate({ environment = { environment, 'table' } })
    local s = ''
    for key, value in pairs(environment) do
        s = s .. key .. '="' .. value .. '",'
    end

    return self:set('environment', s)
end

--- Sets `--log-file <value>`
--- @param value string
--- @return ClientShellCmd
function ClientShellCmd:set_log_file(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('log-file', value)
end

--- Sets `--log-level <value>`
--- @param value 'off'|'error'|'warn'|'info'|'debug'|'trace'
--- @return ClientShellCmd
function ClientShellCmd:set_log_level(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('log-level', value)
end

--- Sets `--persist`
--- @return ClientShellCmd
function ClientShellCmd:set_persist()
    return self:set('persist')
end

--- Sets `--pty`
--- @return ClientShellCmd
function ClientShellCmd:set_pty()
    return self:set('pty')
end

--- Sets `--unix-socket <path>`
--- @param path string
--- @return ClientShellCmd
function ClientShellCmd:set_unix_socket(path)
    vim.validate({ path = { path, 'string' } })
    return self:set('unix-socket', value)
end

--- Sets `--windows-pipe <name>`
--- @param name string
--- @return ClientShellCmd
function ClientShellCmd:set_windows_pipe(name)
    vim.validate({ name = { name, 'string' } })
    return self:set('windows-pipe', name)
end

return ClientShellCmd
