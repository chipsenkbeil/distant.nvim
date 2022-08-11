local BaseCmd = require('distant.client.cmd.base')

--- @class ClientReplCmd: BaseCmd
local ClientReplCmd = BaseCmd:new('client repl', { allowed = {
    'config',
    'cache',
    'connection',
    'format',
    'log-file',
    'log-level',
    'timeout',
    'unix-socket',
    'windows-pipe',
} })

--- Creates new lsp cmd
--- @return ClientReplCmd
function ClientReplCmd:new()
    self.__internal = {}
    return self
end

--- Sets `--config <path>`
--- @param path string
--- @return ClientReplCmd
function ClientReplCmd:set_config(path)
    vim.validate({ path = { path, 'string' } })
    return self:set('config', path)
end

--- Sets `--cache <path>`
--- @param path string
--- @return ClientReplCmd
function ClientReplCmd:set_cache(path)
    vim.validate({ path = { path, 'string' } })
    return self:set('cache', path)
end

--- Sets `--connection <id>`
--- @param id string
--- @return ClientReplCmd
function ClientReplCmd:set_connection(id)
    vim.validate({ id = { id, 'string' } })
    return self:set('connection', id)
end

--- Sets `--format <value>`
--- @param value 'json'|'shell'
--- @return ClientReplCmd
function ClientReplCmd:set_format(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('format', value)
end

--- Sets `--log-file <value>`
--- @param value string
--- @return ClientReplCmd
function ClientReplCmd:set_log_file(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('log-file', value)
end

--- Sets `--log-level <value>`
--- @param value 'off'|'error'|'warn'|'info'|'debug'|'trace'
--- @return ClientReplCmd
function ClientReplCmd:set_log_level(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('log-level', value)
end

--- Sets `--timeout <value>`
--- @param value number #maximum timeout in seconds for network requests (0 is infinite)
--- @return ClientReplCmd
function ClientReplCmd:set_timeout(value)
    vim.validate({ value = { value, 'number' } })
    return self:set('timeout', tostring(value))
end

--- Sets `--unix-socket <path>`
--- @param path string
--- @return ClientReplCmd
function ClientReplCmd:set_unix_socket(path)
    vim.validate({ path = { path, 'string' } })
    return self:set('unix-socket', value)
end

--- Sets `--windows-pipe <name>`
--- @param name string
--- @return ClientReplCmd
function ClientReplCmd:set_windows_pipe(name)
    vim.validate({ name = { name, 'string' } })
    return self:set('windows-pipe', name)
end

return ClientReplCmd
