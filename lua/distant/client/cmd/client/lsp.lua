local BaseCmd = require('distant.client.cmd.base')

--- @class ClientLspCmd: BaseCmd
--- @field __cmd string
local ClientLspCmd = BaseCmd:new('client lsp', { allowed = {
    'config',
    'cache',
    'connection',
    'log-file',
    'log-level',
    'persist',
    'pty',
    'unix-socket',
    'windows-pipe',
} })

--- Creates new lsp cmd
--- @param prog string
--- @return ClientLspCmd
function ClientLspCmd:new(prog)
    self.__internal = {}
    self.__prog = assert(prog, 'Missing prog argument')
    return self
end

--- Returns cmd as a list
--- @return string[]
function ClientLspCmd:as_list()
    local lst = BaseCmd.as_list(self)
    table.insert(lst, '--')
    table.insert(lst, self.__prog)
    return lst
end

--- Sets `--config <path>`
--- @param path string
--- @return ClientLspCmd
function ClientLspCmd:set_config(path)
    vim.validate({ path = { path, 'string' } })
    return self:set('config', path)
end

--- Sets `--cache <path>`
--- @param path string
--- @return ClientLspCmd
function ClientLspCmd:set_cache(path)
    vim.validate({ path = { path, 'string' } })
    return self:set('cache', path)
end

--- Sets `--connection <id>`
--- @param id string
--- @return ClientLspCmd
function ClientLspCmd:set_connection(id)
    vim.validate({ id = { id, 'string' } })
    return self:set('connection', id)
end

--- Sets `--log-file <value>`
--- @param value string
--- @return ClientLspCmd
function ClientLspCmd:set_log_file(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('log-file', value)
end

--- Sets `--log-level <value>`
--- @param value 'off'|'error'|'warn'|'info'|'debug'|'trace'
--- @return ClientLspCmd
function ClientLspCmd:set_log_level(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('log-level', value)
end

--- Sets `--persist`
--- @return ClientLspCmd
function ClientLspCmd:set_persist()
    return self:set('persist')
end

--- Sets `--pty`
--- @return ClientLspCmd
function ClientLspCmd:set_pty()
    return self:set('pty')
end

--- Sets `--unix-socket <path>`
--- @param path string
--- @return ClientLspCmd
function ClientLspCmd:set_unix_socket(path)
    vim.validate({ path = { path, 'string' } })
    return self:set('unix-socket', value)
end

--- Sets `--windows-pipe <name>`
--- @param name string
--- @return ClientLspCmd
function ClientLspCmd:set_windows_pipe(name)
    vim.validate({ name = { name, 'string' } })
    return self:set('windows-pipe', name)
end

return ClientLspCmd
