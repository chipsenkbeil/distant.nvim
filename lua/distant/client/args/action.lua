local BaseArgs = require('distant.client.args.base')

--- @class ActionArgs: BaseArgs
--- @field __subcommand string|nil
local ActionArgs = BaseArgs:new({allowed = {
    'interactive',
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

--- Creates new action args
--- @param subcommand? string
--- @return ActionArgs
function ActionArgs:new(subcommand)
    self.__subcommand = subcommand
    return self
end

--- Returns args as a string for use in a cmd
--- @return string
function ActionArgs:__tostring()
    local s = BaseArgs.__tostring(self)
    if self.__subcommand then
        if #s > 0 then
            s = s .. ' '
        end
        s = s .. self.__subcommand
    end
    return s
end

--- Sets `--interactive`
--- @return ActionArgs
function ActionArgs:set_interactive()
    return self:set('interactive')
end

--- Sets `--format <value>`
--- @param value 'json'|'shell'
--- @return ActionArgs
function ActionArgs:set_format(value)
    vim.validate({value={value, 'string'}})
    return self:set('format', value)
end

--- Sets `--log-file <value>`
--- @param value string
--- @return ActionArgs
function ActionArgs:set_log_file(value)
    vim.validate({value={value, 'string'}})
    return self:set('log-file', value)
end

--- Sets `--log-level <value>`
--- @param value 'off'|'error'|'warn'|'info'|'debug'|'trace'
--- @return ActionArgs
function ActionArgs:set_log_level(value)
    vim.validate({value={value, 'string'}})
    return self:set('log-level', value)
end

--- Sets `--method <value>`
--- @param value 'distant'|'ssh'
--- @return LspArgs
function ActionArgs:set_method(value)
    vim.validate({value={value, 'string'}})
    return self:set('method', value)
end

--- Sets `--session <value>`
--- @param value 'environment'|'file'|'keep'|'pipe'|'socket'
--- @return ActionArgs
function ActionArgs:set_session(value)
    vim.validate({value={value, 'string'}})
    return self:set('session', value)
end

--- Sets `--session-file <value>`
--- @param value string
--- @return ActionArgs
function ActionArgs:set_session_file(value)
    vim.validate({value={value, 'string'}})
    return self:set('session-file', value)
end

--- Sets `--session-socket <value>`
--- @param value string
--- @return ActionArgs
function ActionArgs:set_session_socket(value)
    vim.validate({value={value, 'string'}})
    return self:set('session-socket', value)
end

--- Sets `--ssh-host <value>`
--- @param value string
--- @return ActionArgs
function ActionArgs:set_ssh_host(value)
    vim.validate({value={value, 'string'}})
    return self:set('ssh-host', value)
end

--- Sets `--ssh-port <value>`
--- @param value number
--- @return ActionArgs
function ActionArgs:set_ssh_port(value)
    vim.validate({value={value, 'number'}})
    return self:set('ssh-port', tostring(value))
end

--- Sets `--ssh-user <value>`
--- @param value string
--- @return ActionArgs
function ActionArgs:set_ssh_user(value)
    vim.validate({value={value, 'string'}})
    return self:set('ssh-user', value)
end

--- Sets `--timeout <value>`
--- @param value number #maximum timeout in seconds for network requests (0 is infinite)
--- @return ActionArgs
function ActionArgs:set_timeout(value)
    vim.validate({value={value, 'number'}})
    return self:set('timeout', tostring(value))
end

return ActionArgs
