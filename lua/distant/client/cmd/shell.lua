local BaseCmd = require('distant.client.cmd.base')

--- @class ShellCmd: BaseCmd
--- @field __cmd string
local ShellCmd = BaseCmd:new({ allowed = {
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

--- Creates new shell cmd
--- @param prog? string #optional prog to run instead of $TERM
--- @return ShellCmd
function ShellCmd:new(prog)
    self.__internal = {}
    self.__prog = prog
    return self
end

--- Returns cmd as a list
--- @return string[]
function ShellCmd:as_list()
    local lst = BaseCmd.as_list(self)
    table.insert(lst, '--')
    table.insert(lst, self.__prog)
    return lst
end

--- Sets `--persist`
--- @return ShellCmd
function ShellCmd:set_persist()
    return self:set('persist')
end

--- Sets `--format <value>`
--- @param value 'json'|'shell'
--- @return ShellCmd
function ShellCmd:set_format(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('format', value)
end

--- Sets `--log-file <value>`
--- @param value string
--- @return ShellCmd
function ShellCmd:set_log_file(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('log-file', value)
end

--- Sets `--log-level <value>`
--- @param value 'off'|'error'|'warn'|'info'|'debug'|'trace'
--- @return ShellCmd
function ShellCmd:set_log_level(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('log-level', value)
end

--- Sets `--method <value>`
--- @param value 'distant'|'ssh'
--- @return ShellCmd
function ShellCmd:set_method(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('method', value)
end

--- Sets `--session <value>`
--- @param value 'environment'|'file'|'keep'|'pipe'|'socket'
--- @return ShellCmd
function ShellCmd:set_session(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('session', value)
end

--- Sets `--session-file <value>`
--- @param value string
--- @return ShellCmd
function ShellCmd:set_session_file(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('session-file', value)
end

--- Sets `--session-socket <value>`
--- @param value string
--- @return ShellCmd
function ShellCmd:set_session_socket(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('session-socket', value)
end

--- Sets `--ssh-host <value>`
--- @param value string
--- @return ShellCmd
function ShellCmd:set_ssh_host(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('ssh-host', value)
end

--- Sets `--ssh-port <value>`
--- @param value number
--- @return ShellCmd
function ShellCmd:set_ssh_port(value)
    vim.validate({ value = { value, 'number' } })
    return self:set('ssh-port', tostring(value))
end

--- Sets `--ssh-user <value>`
--- @param value string
--- @return ShellCmd
function ShellCmd:set_ssh_user(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('ssh-user', value)
end

--- Sets `--timeout <value>`
--- @param value number #maximum timeout in seconds for network requests (0 is infinite)
--- @return ShellCmd
function ShellCmd:set_timeout(value)
    vim.validate({ value = { value, 'number' } })
    return self:set('timeout', tostring(value))
end

return ShellCmd
