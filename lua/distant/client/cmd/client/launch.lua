local BaseCmd = require('distant.client.cmd.base')

--- @class ClientLaunchCmd: BaseCmd
--- @field __destination string
local ClientLaunchCmd = BaseCmd:new('client launch', { allowed = {
    'config',
    'cache',
    'distant',
    'distant-args',
    'distant-bind-server',
    'format',
    'log-file',
    'log-level',
    'no-shell',
    'ssh',
    'ssh-backend',
    'ssh-external',
    'ssh-identity-file',
    'ssh-port',
    'ssh-username',
    'unix-socket',
    'windows-pipe',
} })

--- Creates new launch cmd
--- @param destination string
--- @return ClientLaunchCmd
function ClientLaunchCmd:new(destination)
    self.__internal = {}
    self.__destination = destination
    return self
end

--- Returns cmd as a list
--- @return string[]
function ClientLaunchCmd:as_list()
    local lst = BaseCmd.as_list(self)
    table.insert(lst, self.__destination)
    return lst
end

--- Sets `--config <path>`
--- @param path string
--- @return ClientLaunchCmd
function ClientLaunchCmd:set_config(path)
    vim.validate({ path = { path, 'string' } })
    return self:set('config', path)
end

--- Sets `--cache <path>`
--- @param path string
--- @return ClientLaunchCmd
function ClientLaunchCmd:set_cache(path)
    vim.validate({ path = { path, 'string' } })
    return self:set('cache', path)
end

--- Sets `--distant <value>`
--- @param value string
--- @return ClientLaunchCmd
function ClientLaunchCmd:set_distant(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('distant', value)
end

--- Sets `--distant-args "<value> <sep> <by> <space>"`
--- @param value string|string[]|BaseCmd #if a string, will put verbatim as value. If list of strings, will place separated by space. If inherits Baseargs, will call __tostring and insert
--- @return ClientLaunchCmd
function ClientLaunchCmd:set_distant_args(value)
    local svalue
    if vim.tbl_islist(value) then
        svalue = table.concat(value, ' ')
    else
        svalue = tostring(value)
    end

    return self:set('distant-args', svalue)
end

--- Sets `--distant-bind-server <value>`
--- @param value 'ssh'|'any'|string
--- @return ClientLaunchCmd
function ClientLaunchCmd:set_distant_bind_server(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('distant-bind-server', value)
end

--- Sets `--format <value>`
--- @param value 'json'|'shell'
--- @return ClientLaunchCmd
function ClientLaunchCmd:set_format(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('format', value)
end

--- Sets `--log-file <value>`
--- @param value string
--- @return ClientLaunchCmd
function ClientLaunchCmd:set_log_file(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('log-file', value)
end

--- Sets `--log-level <value>`
--- @param value 'off'|'error'|'warn'|'info'|'debug'|'trace'
--- @return ClientLaunchCmd
function ClientLaunchCmd:set_log_level(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('log-level', value)
end

--- Sets `--no-shell`
--- @return ClientLaunchCmd
function ClientLaunchCmd:set_no_shell()
    return self:set('no-shell')
end

--- Sets `--ssh <value>`
--- @param value string
--- @return ClientLaunchCmd
function ClientLaunchCmd:set_ssh(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('ssh', value)
end

--- Sets `--ssh-backend <value>`
--- @param backend 'libssh'|'ssh2'
--- @return ClientLaunchCmd
function ClientLaunchCmd:set_ssh_backend(backend)
    vim.validate({ backend = { backend, 'string' } })
    return self:set('ssh-backend', backend)
end

--- Sets `--ssh-external`
--- @return ClientLaunchCmd
function ClientLaunchCmd:set_ssh_external()
    return self:set('ssh-external')
end

--- Sets `--ssh-identity-file <value>`
--- @param value string
--- @return ClientLaunchCmd
function ClientLaunchCmd:set_ssh_identity_file(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('ssh-identity-file', value)
end

--- Sets `--ssh-port <value>`
--- @param value number
--- @return ClientLaunchCmd
function ClientLaunchCmd:set_ssh_port(value)
    vim.validate({ value = { value, 'number' } })
    return self:set('ssh-port', tostring(value))
end

--- Sets `--ssh-username <value>`
--- @param value string #username to use when ssh'ing into machine
--- @return ClientLaunchCmd
function ClientLaunchCmd:set_ssh_username(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('ssh-username', value)
end

--- Sets `--unix-socket <path>`
--- @param path string
--- @return ClientLaunchCmd
function ClientLaunchCmd:set_unix_socket(path)
    vim.validate({ path = { path, 'string' } })
    return self:set('unix-socket', value)
end

--- Sets `--windows-pipe <name>`
--- @param name string
--- @return ClientLaunchCmd
function ClientLaunchCmd:set_windows_pipe(name)
    vim.validate({ name = { name, 'string' } })
    return self:set('windows-pipe', name)
end

return ClientLaunchCmd
