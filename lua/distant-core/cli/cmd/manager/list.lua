local BaseCmd = require('distant-core.cli.cmd.base')

--- @class ManagerListCmd: BaseCmd
local ManagerListCmd = BaseCmd:new('manager list', {
    allowed = {
        'cache',
        'config',
        'log-file',
        'log-level',
        'unix-socket',
        'windows-pipe',
    }
})

--- Creates new `manager list` cmd
--- @return ManagerListCmd
function ManagerListCmd:new()
    self.__internal = {}
    return self
end

--- Sets `--cache <path>`
--- @param path string
--- @return ManagerListCmd
function ManagerListCmd:set_cache(path)
    vim.validate({ path = { path, 'string' } })
    return self:set('cache', path)
end

--- Sets `--config <path>`
--- @param path string
--- @return ManagerListCmd
function ManagerListCmd:set_config(path)
    vim.validate({ path = { path, 'string' } })
    return self:set('config', path)
end

--- Sets `--log-file <value>`
--- @param value string
--- @return ManagerListCmd
function ManagerListCmd:set_log_file(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('log-file', value)
end

--- Sets `--log-level <value>`
--- @param value 'off'|'error'|'warn'|'info'|'debug'|'trace'
--- @return ManagerListCmd
function ManagerListCmd:set_log_level(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('log-level', value)
end

--- Sets `--unix-socket <path>`
--- @param path string
--- @return ManagerListCmd
function ManagerListCmd:set_unix_socket(path)
    vim.validate({ path = { path, 'string' } })
    return self:set('unix-socket', path)
end

--- Sets `--windows-pipe <name>`
--- @param name string
--- @return ManagerListCmd
function ManagerListCmd:set_windows_pipe(name)
    vim.validate({ name = { name, 'string' } })
    return self:set('windows-pipe', name)
end

return ManagerListCmd
