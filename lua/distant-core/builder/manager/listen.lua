local Cmd = require('distant-core.builder.cmd')

--- @class DistantManagerListenCmdBuilder
--- @field cmd DistantCmdBuilder
local M = {}
M.__index = M

--- Creates new `manager listen` cmd
--- @return DistantManagerListenCmdBuilder
function M:new()
    local instance = {}
    setmetatable(instance, M)

    instance.cmd = Cmd:new('manager listen', {
        allowed = {
            'access',
            'config',
            'daemon',
            'log-file',
            'log-level',
            'unix-socket',
            'user',
            'windows-pipe',
        }
    })

    return instance
end

--- Sets `--access <value>`
--- @param value 'owner'|'group'|'anyone'
--- @return DistantManagerListenCmdBuilder
function M:set_access(value)
    vim.validate({ value = { value, 'string' } })
    self.cmd:set('access', value)
    return self
end

--- Sets `--config <path>`
--- @param path string
--- @return DistantManagerListenCmdBuilder
function M:set_config(path)
    vim.validate({ path = { path, 'string' } })
    self.cmd:set('config', path)
    return self
end

--- Sets `--daemon` flag
--- @return DistantManagerListenCmdBuilder
function M:set_daemon()
    self.cmd:set('daemon')
    return self
end

--- Sets `--log-file <value>`
--- @param value string
--- @return DistantManagerListenCmdBuilder
function M:set_log_file(value)
    vim.validate({ value = { value, 'string' } })
    self.cmd:set('log-file', value)
    return self
end

--- Sets `--log-level <value>`
--- @param value 'off'|'error'|'warn'|'info'|'debug'|'trace'
--- @return DistantManagerListenCmdBuilder
function M:set_log_level(value)
    vim.validate({ value = { value, 'string' } })
    self.cmd:set('log-level', value)
    return self
end

--- Sets `--unix-socket <path>`
--- @param path string
--- @return DistantManagerListenCmdBuilder
function M:set_unix_socket(path)
    vim.validate({ path = { path, 'string' } })
    self.cmd:set('unix-socket', path)
    return self
end

--- Sets `--user` flag
--- @return DistantManagerListenCmdBuilder
function M:set_user()
    self.cmd:set('user')
    return self
end

--- Sets `--windows-pipe <name>`
--- @param name string
--- @return DistantManagerListenCmdBuilder
function M:set_windows_pipe(name)
    vim.validate({ name = { name, 'string' } })
    self.cmd:set('windows-pipe', name)
    return self
end

-------------------------------------------------------------------------------
--- CONVERSIONS
-------------------------------------------------------------------------------

--- Converts cmd into a list of string.
--- @return string[]
function M:as_list()
    return self.cmd:as_list()
end

--- Returns cmd as a string.
--- @return string
function M:as_string()
    return self.cmd:as_string()
end

--- Returns cmd as a string.
--- @return string
function M:__tostring()
    return self.cmd:__tostring()
end

return M
