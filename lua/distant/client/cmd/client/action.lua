local BaseCmd = require('distant.client.cmd.base')

--- @class ClientActionCmd: BaseCmd
--- @field __subcommand BaseCmd|nil
local ClientActionCmd = BaseCmd:new('client action', { allowed = {
    'config',
    'cache',
    'connection',
    'log-file',
    'log-level',
    'timeout',
    'unix-socket',
    'windows-pipe',
} })

--- Creates new action cmd
--- @param subcommand? BaseCmd
--- @return ClientActionCmd
function ClientActionCmd:new(subcommand)
    self.__internal = {}
    self.__subcommand = subcommand
    return self
end

--- Returns cmd as a list
--- @return string[]
function ClientActionCmd:as_list()
    local lst = BaseCmd.as_list(self)
    if self.__subcommand then
        for _, itm in ipairs(self.__subcommand:as_list()) do
            table.insert(lst, itm)
        end
    end
    return lst
end

--- Sets `--config <path>`
--- @param path string
--- @return ClientActionCmd
function ClientActionCmd:set_config(path)
    vim.validate({ path = { path, 'string' } })
    return self:set('config', path)
end

--- Sets `--cache <path>`
--- @param path string
--- @return ClientActionCmd
function ClientActionCmd:set_cache(path)
    vim.validate({ path = { path, 'string' } })
    return self:set('cache', path)
end

--- Sets `--connection <id>`
--- @param id string
--- @return ClientActionCmd
function ClientActionCmd:set_connection(id)
    vim.validate({ id = { id, 'string' } })
    return self:set('connection', id)
end

--- Sets `--log-file <value>`
--- @param value string
--- @return ClientActionCmd
function ClientActionCmd:set_log_file(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('log-file', value)
end

--- Sets `--log-level <value>`
--- @param value 'off'|'error'|'warn'|'info'|'debug'|'trace'
--- @return ClientActionCmd
function ClientActionCmd:set_log_level(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('log-level', value)
end

--- Sets `--timeout <value>`
--- @param value number #maximum timeout in seconds for network requests (0 is infinite)
--- @return ClientActionCmd
function ClientActionCmd:set_timeout(value)
    vim.validate({ value = { value, 'number' } })
    return self:set('timeout', tostring(value))
end

--- Sets `--unix-socket <path>`
--- @param path string
--- @return ClientActionCmd
function ClientActionCmd:set_unix_socket(path)
    vim.validate({ path = { path, 'string' } })
    return self:set('unix-socket', value)
end

--- Sets `--windows-pipe <name>`
--- @param name string
--- @return ClientActionCmd
function ClientActionCmd:set_windows_pipe(name)
    vim.validate({ name = { name, 'string' } })
    return self:set('windows-pipe', name)
end

return ClientActionCmd
