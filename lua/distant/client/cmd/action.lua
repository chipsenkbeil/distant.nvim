local BaseCmd = require('distant.client.cmd.base')

--- @class ActionCmd: BaseCmd
--- @field __subcommand BaseCmd|nil
local ActionCmd = BaseCmd:new('action', { allowed = {
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
} })

--- Creates new action cmd
--- @param subcommand? BaseCmd
--- @return ActionCmd
function ActionCmd:new(subcommand)
    self.__internal = {}
    self.__subcommand = subcommand
    return self
end

--- Returns cmd as a list
--- @return string[]
function ActionCmd:as_list()
    local lst = BaseCmd.as_list(self)
    if self.__subcommand then
        for _, itm in ipairs(self.__subcommand:as_list()) do
            table.insert(lst, itm)
        end
    end
    return lst
end

--- Sets `--interactive`
--- @return ActionCmd
function ActionCmd:set_interactive()
    return self:set('interactive')
end

--- Sets `--format <value>`
--- @param value 'json'|'shell'
--- @return ActionCmd
function ActionCmd:set_format(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('format', value)
end

--- Sets `--log-file <value>`
--- @param value string
--- @return ActionCmd
function ActionCmd:set_log_file(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('log-file', value)
end

--- Sets `--log-level <value>`
--- @param value 'off'|'error'|'warn'|'info'|'debug'|'trace'
--- @return ActionCmd
function ActionCmd:set_log_level(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('log-level', value)
end

--- Sets `--method <value>`
--- @param value 'distant'|'ssh'
--- @return LspCmd
function ActionCmd:set_method(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('method', value)
end

--- Sets `--session <value>`
--- @param value 'environment'|'file'|'keep'|'pipe'|'socket'
--- @return ActionCmd
function ActionCmd:set_session(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('session', value)
end

--- Sets `--session-file <value>`
--- @param value string
--- @return ActionCmd
function ActionCmd:set_session_file(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('session-file', value)
end

--- Sets `--session-socket <value>`
--- @param value string
--- @return ActionCmd
function ActionCmd:set_session_socket(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('session-socket', value)
end

--- Sets `--ssh-host <value>`
--- @param value string
--- @return ActionCmd
function ActionCmd:set_ssh_host(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('ssh-host', value)
end

--- Sets `--ssh-port <value>`
--- @param value number
--- @return ActionCmd
function ActionCmd:set_ssh_port(value)
    vim.validate({ value = { value, 'number' } })
    return self:set('ssh-port', tostring(value))
end

--- Sets `--ssh-user <value>`
--- @param value string
--- @return ActionCmd
function ActionCmd:set_ssh_user(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('ssh-user', value)
end

--- Sets `--timeout <value>`
--- @param value number #maximum timeout in seconds for network requests (0 is infinite)
--- @return ActionCmd
function ActionCmd:set_timeout(value)
    vim.validate({ value = { value, 'number' } })
    return self:set('timeout', tostring(value))
end

return ActionCmd
