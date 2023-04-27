local Cmd = require('distant-core.builder.cmd')

--- @class DistantServerListenCmdBuilder
--- @field cmd DistantCmdBuilder
local M = {}
M.__index = M

--- Creates new `server listen` cmd
--- @return DistantServerListenCmdBuilder
function M:new()
    local instance = {}
    setmetatable(instance, M)

    instance.cmd = Cmd:new('server listen', {
        allowed = {
            'foreground',
            'key-from-stdin',
            'use-ipv6',
            'current-dir',
            'host',
            'log-file',
            'log-level',
            'max-msg-capacity',
            'port',
            'shutdown',
            'timeout',
        }
    })

    return instance
end

--- Sets `--foreground`
--- @return DistantServerListenCmdBuilder
function M:set_foreground()
    self.cmd:set('foreground')
    return self
end

--- Sets `--key-from-stdin`
--- @return DistantServerListenCmdBuilder
function M:set_key_from_stdin()
    self.cmd:set('key-from-stdin')
    return self
end

--- Sets `--use-ipv6`
--- @return DistantServerListenCmdBuilder
function M:set_use_ipv6()
    self.cmd:set('use-ipv6')
    return self
end

--- Sets `--current-dir <value>`
--- @param value string
--- @return DistantServerListenCmdBuilder
function M:set_current_dir(value)
    vim.validate({ value = { value, 'string' } })
    self.cmd:set('current-dir', value)
    return self
end

--- Sets `--host <value>`
--- @param value 'ssh'|'any'|string
--- @return DistantServerListenCmdBuilder
function M:set_host(value)
    vim.validate({ value = { value, 'string' } })
    self.cmd:set('host', value)
    return self
end

--- Sets `--log-file <value>`
--- @param value string
--- @return DistantServerListenCmdBuilder
function M:set_log_file(value)
    vim.validate({ value = { value, 'string' } })
    self.cmd:set('log-file', value)
    return self
end

--- Sets `--log-level <value>`
--- @param value 'off'|'error'|'warn'|'info'|'debug'|'trace'
--- @return DistantServerListenCmdBuilder
function M:set_log_level(value)
    vim.validate({ value = { value, 'string' } })
    self.cmd:set('log-level', value)
    return self
end

--- Sets `--max-msg-capacity <value>`
--- @param value number
--- @return DistantServerListenCmdBuilder
function M:set_max_msg_capacity(value)
    vim.validate({ value = { value, 'number' } })
    self.cmd:set('max-msg-capacity', tostring(value))
    return self
end

--- Sets `--port <value>[:n]`
--- @param value number
--- @param n? number #if provided, tries a range of ports from <value> to <n>
--- @return DistantServerListenCmdBuilder
function M:set_port(value, n)
    vim.validate({ value = { value, 'number' }, n = { n, 'number', true } })

    local port = tostring(value)
    if type(n) == 'number' then
        port = port .. ':' .. tostring(n)
    end

    self.cmd:set('port', port)
    return self
end

--- Sets `--shutdown <key>[=<value>]`
--- @param key 'after'|'lonely'|'never' #rule type
--- @param value number|nil #time in seconds
--- @return DistantServerListenCmdBuilder
function M:set_shutdown(key, value)
    vim.validate({
        key = { key, 'string' },
        value = { value, 'number' }
    })

    local shutdown_value = key
    if value ~= nil then
        shutdown_value = shutdown_value .. '=' .. tostring(value)
    end

    self.cmd:set('shutdown', shutdown_value)
    return self
end

--- Sets `--timeout <value>`
--- @param value number #maximum timeout in seconds for network requests (0 is infinite)
--- @return DistantServerListenCmdBuilder
function M:set_timeout(value)
    vim.validate({ value = { value, 'number' } })
    self.cmd:set('timeout', tostring(value))
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
