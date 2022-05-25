local BaseArgs = require('distant.client.args.base')

--- @class LspArgs: BaseArgs
--- @field __cmd string
local LspArgs = BaseArgs:new({allowed = {
    'persist',
    'pty',
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
}})

--- Creates new lsp args
--- @param cmd string
--- @return LspArgs
function LspArgs:new(cmd)
    self.__internal = {}
    self.__cmd = cmd
    return self
end

--- Returns args as a string for use in a cmd
--- @return string
function LspArgs:__tostring()
    local s = BaseArgs.__tostring(self)
    if #s > 0 then
        s = s .. ' '
    end
    return s .. self.__cmd
end

--- Sets `--persist`
--- @return LspArgs
function LspArgs:set_persist()
    return self:set('persist')
end

--- Sets `--pty`
--- @return LspArgs
function LspArgs:set_pty()
    return self:set('pty')
end

--- Sets `--format <value>`
--- @param value 'json'|'shell'
--- @return LspArgs
function LspArgs:set_format(value)
    vim.validate({value={value, 'string'}})
    return self:set('format', value)
end

--- Sets `--log-file <value>`
--- @param value string
--- @return LspArgs
function LspArgs:set_log_file(value)
    vim.validate({value={value, 'string'}})
    return self:set('log-file', value)
end

--- Sets `--log-level <value>`
--- @param value 'off'|'error'|'warn'|'info'|'debug'|'trace'
--- @return LspArgs
function LspArgs:set_log_level(value)
    vim.validate({value={value, 'string'}})
    return self:set('log-level', value)
end

--- Sets `--method <value>`
--- @param value 'distant'|'ssh'
--- @return LspArgs
function LspArgs:set_method(value)
    vim.validate({value={value, 'string'}})
    return self:set('method', value)
end

--- Sets `--session <value>`
--- @param value 'environment'|'file'|'keep'|'pipe'|'socket'
--- @return LspArgs
function LspArgs:set_session(value)
    vim.validate({value={value, 'string'}})
    return self:set('session', value)
end

--- Sets `--session-file <value>`
--- @param value string
--- @return LspArgs
function LspArgs:set_session_file(value)
    vim.validate({value={value, 'string'}})
    return self:set('session-file', value)
end

--- Sets `--session-socket <value>`
--- @param value string
--- @return LspArgs
function LspArgs:set_session_socket(value)
    vim.validate({value={value, 'string'}})
    return self:set('session-socket', value)
end

--- Sets `--ssh-host <value>`
--- @param value string
--- @return LspArgs
function LspArgs:set_ssh_host(value)
    vim.validate({value={value, 'string'}})
    return self:set('ssh-host', value)
end

--- Sets `--ssh-port <value>`
--- @param value number
--- @return LspArgs
function LspArgs:set_ssh_port(value)
    vim.validate({value={value, 'number'}})
    return self:set('ssh-port', tostring(value))
end

--- Sets `--ssh-user <value>`
--- @param value string
--- @return LspArgs
function LspArgs:set_ssh_user(value)
    vim.validate({value={value, 'string'}})
    return self:set('ssh-user', value)
end

--- Sets `--timeout <value>`
--- @param value number #maximum timeout in seconds for network requests (0 is infinite)
--- @return LspArgs
function LspArgs:set_timeout(value)
    vim.validate({value={value, 'number'}})
    return self:set('timeout', tostring(value))
end

return LspArgs
