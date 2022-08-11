local BaseCmd = require('distant.client.cmd.base')

--- @class ManagerListenCmd: BaseCmd
local ManagerListenCmd = BaseCmd:new('manager listen', { allowed = {
    'access',
    'config',
    'daemon',
    'log-file',
    'log-level',
    'unix-socket',
    'user',
    'windows-pipe',
} })

--- Creates new `manager listen` cmd
--- @return ManagerListenCmd
function ManagerListenCmd:new()
    self.__internal = {}
    return self
end

--- Sets `--access <value>`
--- @param value 'owner'|'group'|'anyone'
--- @return ManagerListenCmd
function ManagerListenCmd:set_access(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('access', value)
end

--- Sets `--config <path>`
--- @param path string
--- @return ManagerListenCmd
function ManagerListenCmd:set_config(path)
    vim.validate({ path = { path, 'string' } })
    return self:set('config', path)
end

--- Sets `--daemon` flag
--- @return ManagerListenCmd
function ManagerListenCmd:set_daemon()
    return self:set('daemon')
end

--- Sets `--log-file <value>`
--- @param value string
--- @return ManagerListenCmd
function ManagerListenCmd:set_log_file(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('log-file', value)
end

--- Sets `--log-level <value>`
--- @param value 'off'|'error'|'warn'|'info'|'debug'|'trace'
--- @return ManagerListenCmd
function ManagerListenCmd:set_log_level(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('log-level', value)
end

--- Sets `--unix-socket <path>`
--- @param path string
--- @return ManagerListenCmd
function ManagerListenCmd:set_unix_socket(path)
    vim.validate({ path = { path, 'string' } })
    return self:set('unix-socket', path)
end

--- Sets `--user` flag
--- @return ManagerListenCmd
function ManagerListenCmd:set_user()
    return self:set('user')
end

--- Sets `--windows-pipe <name>`
--- @param name string
--- @return ManagerListenCmd
function ManagerListenCmd:set_windows_pipe(name)
    vim.validate({ name = { name, 'string' } })
    return self:set('windows-pipe', name)
end

return ManagerListenCmd
