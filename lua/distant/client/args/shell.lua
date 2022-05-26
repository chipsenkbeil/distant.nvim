local BaseArgs = require('distant.client.args.base')

--- @class ShellArgs: BaseArgs
--- @field __cmd string
local ShellArgs = BaseArgs:new({ allowed = {
    'persist',
    'format',
    'log-file',
    'log-level',
    'method',
    'session',
    'session-file',
    'session-socket',
    'ssh-host',
    'ssh-port',
    'ssh-user',
    'timeout',
} })

--- Creates new shell args
--- @param cmd? string #optional cmd to run instead of $TERM
--- @return ShellArgs
function ShellArgs:new(cmd)
    self.__internal = {}
    self.__cmd = cmd
    return self
end

--- Returns args as a string for use in a cmd
--- @return string
function ShellArgs:__tostring()
    local s = BaseArgs.__tostring(self)
    if #s > 0 then
        s = s .. ' '
    end
    return s .. self.__cmd
end

--- Sets `--persist`
--- @return ShellArgs
function ShellArgs:set_persist()
    return self:set('persist')
end

--- Sets `--format <value>`
--- @param value 'json'|'shell'
--- @return ShellArgs
function ShellArgs:set_format(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('format', value)
end

--- Sets `--log-file <value>`
--- @param value string
--- @return ShellArgs
function ShellArgs:set_log_file(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('log-file', value)
end

--- Sets `--log-level <value>`
--- @param value 'off'|'error'|'warn'|'info'|'debug'|'trace'
--- @return ShellArgs
function ShellArgs:set_log_level(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('log-level', value)
end

--- Sets `--method <value>`
--- @param value 'distant'|'ssh'
--- @return ShellArgs
function ShellArgs:set_method(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('method', value)
end

--- Sets `--session <value>`
--- @param value 'environment'|'file'|'keep'|'pipe'|'socket'
--- @return ShellArgs
function ShellArgs:set_session(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('session', value)
end

--- Sets `--session-file <value>`
--- @param value string
--- @return ShellArgs
function ShellArgs:set_session_file(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('session-file', value)
end

--- Sets `--session-socket <value>`
--- @param value string
--- @return ShellArgs
function ShellArgs:set_session_socket(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('session-socket', value)
end

--- Sets `--ssh-host <value>`
--- @param value string
--- @return ShellArgs
function ShellArgs:set_ssh_host(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('ssh-host', value)
end

--- Sets `--ssh-port <value>`
--- @param value number
--- @return ShellArgs
function ShellArgs:set_ssh_port(value)
    vim.validate({ value = { value, 'number' } })
    return self:set('ssh-port', tostring(value))
end

--- Sets `--ssh-user <value>`
--- @param value string
--- @return ShellArgs
function ShellArgs:set_ssh_user(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('ssh-user', value)
end

--- Sets `--timeout <value>`
--- @param value number #maximum timeout in seconds for network requests (0 is infinite)
--- @return ShellArgs
function ShellArgs:set_timeout(value)
    vim.validate({ value = { value, 'number' } })
    return self:set('timeout', tostring(value))
end

return ShellArgs
