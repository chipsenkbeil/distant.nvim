local BaseCmd = require('distant.client.cmd.base')

--- @class ListenCmd: BaseCmd
local ListenCmd = BaseCmd:new('listen', { allowed = {
    'foreground',
    'key-from-stdin',
    'use-ipv6',
    'current-dir',
    'host',
    'log-file',
    'log-level',
    'max-msg-capacity',
    'port',
    'shutdown-after',
    'timeout',
} })

--- Creates new lsp cmd
--- @return ListenCmd
function ListenCmd:new()
    self.__internal = {}
    return self
end

--- Sets `--foreground`
--- @return ListenCmd
function ListenCmd:set_foreground()
    return self:set('foreground')
end

--- Sets `--key-from-stdin`
--- @return ListenCmd
function ListenCmd:set_key_from_stdin()
    return self:set('key-from-stdin')
end

--- Sets `--use-ipv6`
--- @return ListenCmd
function ListenCmd:set_use_ipv6()
    return self:set('use-ipv6')
end

--- Sets `--current-dir <value>`
--- @param value string
--- @return ListenCmd
function ListenCmd:set_current_dir(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('current-dir', value)
end

--- Sets `--host <value>`
--- @param value 'ssh'|'any'|string
--- @return ListenCmd
function ListenCmd:set_host(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('host', value)
end

--- Sets `--log-file <value>`
--- @param value string
--- @return ListenCmd
function ListenCmd:set_log_file(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('log-file', value)
end

--- Sets `--log-level <value>`
--- @param value 'off'|'error'|'warn'|'info'|'debug'|'trace'
--- @return ListenCmd
function ListenCmd:set_log_level(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('log-level', value)
end

--- Sets `--max-msg-capacity <value>`
--- @param value number
--- @return ListenCmd
function ListenCmd:set_max_msg_capacity(value)
    vim.validate({ value = { value, 'number' } })
    return self:set('max-msg-capacity', tostring(value))
end

--- Sets `--port <value>[:n]`
--- @param value number
--- @param n? number #if provided, tries a range of ports from <value> to <n>
--- @return ListenCmd
function ListenCmd:set_port(value, n)
    vim.validate({ value = { value, 'number' }, n = { n, 'number', true } })

    local port = tostring(value)
    if type(n) == 'number' then
        port = port .. ':' .. tostring(n)
    end

    return self:set('port', port)
end

--- Sets `--shutdown-after <value>`
--- @param value number #time in seconds
--- @return ListenCmd
function ListenCmd:set_shutdown_after(value)
    vim.validate({ value = { value, 'number' } })
    return self:set('shutdown-after', tostring(value))
end

--- Sets `--timeout <value>`
--- @param value number #maximum timeout in seconds for network requests (0 is infinite)
--- @return ListenCmd
function ListenCmd:set_timeout(value)
    vim.validate({ value = { value, 'number' } })
    return self:set('timeout', tostring(value))
end

return ListenCmd
