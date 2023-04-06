local BaseCmd = require('distant-core.cli.cmd.base')

--- @class ClientSelectCmd: BaseCmd
--- @field __destination string
local ClientSelectCmd = BaseCmd:new('client select', {
    allowed = {
        'config',
        'cache',
        'format',
        'log-file',
        'log-level',
        'unix-socket',
        'windows-pipe',
    }
})

--- Creates new action cmd
--- @param connection string|nil #optional connection id to select
--- @return ClientSelectCmd
function ClientSelectCmd:new(connection)
    self.__internal = {}
    self.__connection = connection
    return self
end

--- Returns cmd as a list
--- @return string[]
function ClientSelectCmd:as_list()
    local lst = BaseCmd.as_list(self)
    if self.__connection then
        table.insert(lst, self.__connection)
    end
    return lst
end

--- Sets `--config <path>`
--- @param path string
--- @return ClientSelectCmd
function ClientSelectCmd:set_config(path)
    vim.validate({ path = { path, 'string' } })
    return self:set('config', path)
end

--- Sets `--cache <path>`
--- @param path string
--- @return ClientSelectCmd
function ClientSelectCmd:set_cache(path)
    vim.validate({ path = { path, 'string' } })
    return self:set('cache', path)
end

--- Sets `--format <format>`
--- @param format 'json'|'shell'
--- @return ClientSelectCmd
function ClientSelectCmd:set_format(format)
    vim.validate({ format = { format, 'string' } })
    return self:set('format', format)
end

--- Sets `--log-file <value>`
--- @param value string
--- @return ClientSelectCmd
function ClientSelectCmd:set_log_file(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('log-file', value)
end

--- Sets `--log-level <value>`
--- @param value 'off'|'error'|'warn'|'info'|'debug'|'trace'
--- @return ClientSelectCmd
function ClientSelectCmd:set_log_level(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('log-level', value)
end

--- Sets `--unix-socket <path>`
--- @param path string
--- @return ClientSelectCmd
function ClientSelectCmd:set_unix_socket(path)
    vim.validate({ path = { path, 'string' } })
    return self:set('unix-socket', value)
end

--- Sets `--windows-pipe <name>`
--- @param name string
--- @return ClientSelectCmd
function ClientSelectCmd:set_windows_pipe(name)
    vim.validate({ name = { name, 'string' } })
    return self:set('windows-pipe', name)
end

return ClientSelectCmd
