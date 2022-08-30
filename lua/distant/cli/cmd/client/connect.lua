local BaseCmd = require('distant.cli.cmd.base')

--- @class ClientConnectCmd: BaseCmd
--- @field __destination string
local ClientConnectCmd = BaseCmd:new('client connect', { allowed = {
    'config',
    'cache',
    'format',
    'log-file',
    'log-level',
    'options',
    'unix-socket',
    'windows-pipe',
} })

--- Creates new action cmd
--- @param destination string
--- @return ClientConnectCmd
function ClientConnectCmd:new(destination)
    self.__internal = {}
    self.__destination = destination
    return self
end

--- Returns cmd as a list
--- @return string[]
function ClientConnectCmd:as_list()
    local lst = BaseCmd.as_list(self)
    table.insert(lst, self.__destination)
    return lst
end

--- Sets `--config <path>`
--- @param path string
--- @return ClientConnectCmd
function ClientConnectCmd:set_config(path)
    vim.validate({ path = { path, 'string' } })
    return self:set('config', path)
end

--- Sets `--cache <path>`
--- @param path string
--- @return ClientConnectCmd
function ClientConnectCmd:set_cache(path)
    vim.validate({ path = { path, 'string' } })
    return self:set('cache', path)
end

--- Sets `--format <format>`
--- @param format 'json'|'shell'
--- @return ClientConnectCmd
function ClientConnectCmd:set_format(format)
    vim.validate({ format = { format, 'string' } })
    return self:set('format', format)
end

--- Sets `--log-file <value>`
--- @param value string
--- @return ClientConnectCmd
function ClientConnectCmd:set_log_file(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('log-file', value)
end

--- Sets `--log-level <value>`
--- @param value 'off'|'error'|'warn'|'info'|'debug'|'trace'
--- @return ClientConnectCmd
function ClientConnectCmd:set_log_level(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('log-level', value)
end

--- Sets `--options <options>`
--- @param options string
--- @return ClientConnectCmd
function ClientConnectCmd:set_options(options)
    vim.validate({ options = { options, 'string' } })
    return self:set('options', options)
end

--- Sets `--unix-socket <path>`
--- @param path string
--- @return ClientConnectCmd
function ClientConnectCmd:set_unix_socket(path)
    vim.validate({ path = { path, 'string' } })
    return self:set('unix-socket', value)
end

--- Sets `--windows-pipe <name>`
--- @param name string
--- @return ClientConnectCmd
function ClientConnectCmd:set_windows_pipe(name)
    vim.validate({ name = { name, 'string' } })
    return self:set('windows-pipe', name)
end

return ClientConnectCmd
