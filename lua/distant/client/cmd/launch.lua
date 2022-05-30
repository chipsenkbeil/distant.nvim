local BaseCmd = require('distant.client.cmd.base')

--- @class LaunchCmd: BaseCmd
--- @field __host string
local LaunchCmd = BaseCmd:new('launch', { allowed = {
    'external-ssh',
    'fail-if-socket-exists',
    'foreground',
    'no-shell',
    'bind-server',
    'distant',
    'extra-server-args',
    'format',
    'identity-file',
    'log-file',
    'log-level',
    'port',
    'session',
    'session-file',
    'session-socket',
    'shutdown-after',
    'ssh',
    'timeout',
    'username',
} })

--- Creates new launch cmd
--- @param host string
--- @return LaunchCmd
function LaunchCmd:new(host)
    self.__internal = {}
    self.__host = host
    return self
end

--- Returns cmd as a list
--- @return string[]
function LaunchCmd:as_list()
    local lst = BaseCmd.as_list(self)
    table.insert(lst, self.__host)
    return lst
end

--- Sets `--external-ssh`
--- @return LaunchCmd
function LaunchCmd:set_external_ssh()
    return self:set('external-ssh')
end

--- Sets `--fail-if-socket-exists`
--- @return LaunchCmd
function LaunchCmd:set_fail_if_socket_exists()
    return self:set('fail-if-socket-exists')
end

--- Sets `--foreground`
--- @return LaunchCmd
function LaunchCmd:set_foreground()
    return self:set('foreground')
end

--- Sets `--no-shell`
--- @return LaunchCmd
function LaunchCmd:set_no_shell()
    return self:set('no-shell')
end

--- Sets `--bind-server <value>`
--- @param value 'ssh'|'any'|string
--- @return LaunchCmd
function LaunchCmd:set_bind_server(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('bind-server', value)
end

--- Sets `--distant <value>`
--- @param value string
--- @return LaunchCmd
function LaunchCmd:set_distant(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('distant', value)
end

--- Sets `--extra-server-args "<value> <sep> <by> <space>"`
--- @param value string|string[]|BaseCmd #if a string, will put verbatim as value. If list of strings, will place separated by space. If inherits Baseargs, will call __tostring and insert
--- @return LaunchCmd
function LaunchCmd:set_extra_server_args(value)
    local svalue
    if vim.tbl_islist(value) then
        svalue = table.concat(value, ' ')
    else
        svalue = tostring(value)
    end

    return self:set('extra-server-args', svalue)
end

--- Sets `--format <value>`
--- @param value 'json'|'shell'
--- @return LaunchCmd
function LaunchCmd:set_format(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('format', value)
end

--- Sets `--identity-file <value>`
--- @param value string
--- @return LaunchCmd
function LaunchCmd:set_identity_file(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('identity-file', value)
end

--- Sets `--log-file <value>`
--- @param value string
--- @return LaunchCmd
function LaunchCmd:set_log_file(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('log-file', value)
end

--- Sets `--log-level <value>`
--- @param value 'off'|'error'|'warn'|'info'|'debug'|'trace'
--- @return LaunchCmd
function LaunchCmd:set_log_level(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('log-level', value)
end

--- Sets `--port <value>`
--- @param value number
--- @return LaunchCmd
function LaunchCmd:set_port(value)
    vim.validate({ value = { value, 'number' } })
    return self:set('port', tostring(value))
end

--- Sets `--session <value>`
--- @param value 'environment'|'file'|'keep'|'pipe'|'socket'
--- @return LaunchCmd
function LaunchCmd:set_session(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('session', value)
end

--- Sets `--session-file <value>`
--- @param value string
--- @return LaunchCmd
function LaunchCmd:set_session_file(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('session-file', value)
end

--- Sets `--session-socket <value>`
--- @param value string
--- @return LaunchCmd
function LaunchCmd:set_session_socket(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('session-socket', value)
end

--- Sets `--shutdown-after <value>`
--- @param value number #time in seconds
--- @return LaunchCmd
function LaunchCmd:set_shutdown_after(value)
    vim.validate({ value = { value, 'number' } })
    return self:set('shutdown-after', tostring(value))
end

--- Sets `--ssh <value>`
--- @param value string
--- @return LaunchCmd
function LaunchCmd:set_ssh(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('ssh', value)
end

--- Sets `--timeout <value>`
--- @param value number #maximum timeout in seconds for network requests (0 is infinite)
--- @return LaunchCmd
function LaunchCmd:set_timeout(value)
    vim.validate({ value = { value, 'number' } })
    return self:set('timeout', tostring(value))
end

--- Sets `--username <value>`
--- @param value string #username to use when ssh'ing into machine
--- @return LaunchCmd
function LaunchCmd:set_username(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('username', value)
end

return LaunchCmd
