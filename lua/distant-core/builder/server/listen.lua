local CmdBuilder = require('distant-core.builder.cmd')

--- @class distant.core.builder.server.ListenCmdBuilder
--- @field cmd distant.core.builder.CmdBuilder
local M = {}
M.__index = M

--- Creates new `server listen` cmd.
--- @return distant.core.builder.server.ListenCmdBuilder
function M:new()
    local instance = {}
    setmetatable(instance, M)

    instance.cmd = CmdBuilder:new('server listen', {
        allowed = {
            'config',
            'current-dir',
            'daemon',
            'host',
            'key-from-stdin',
            'log-file',
            'log-level',
            'port',
            'shutdown',
            'timeout',
            'use-ipv6',
        }
    })

    return instance
end

--- Sets multiple arguments using the given table.
--- @param tbl table<string, boolean|string>
--- @return distant.core.builder.server.ListenCmdBuilder
function M:set_from_tbl(tbl)
    self.cmd:set_from_tbl(tbl)
    return self
end

--- Sets `--config <path>`
--- @param path string
--- @return distant.core.builder.server.ListenCmdBuilder
function M:set_config(path)
    vim.validate({ path = { path, 'string' } })
    self.cmd:set('config', path)
    return self
end

--- Sets `--current-dir <value>`
--- @param value string
--- @return distant.core.builder.server.ListenCmdBuilder
function M:set_current_dir(value)
    vim.validate({ value = { value, 'string' } })
    self.cmd:set('current-dir', value)
    return self
end

--- Sets `--daemon`
--- @return distant.core.builder.server.ListenCmdBuilder
function M:set_daemon()
    self.cmd:set('daemon')
    return self
end

--- Sets `--host <value>`
--- @param value 'ssh'|'any'|string
--- @return distant.core.builder.server.ListenCmdBuilder
function M:set_host(value)
    vim.validate({ value = { value, 'string' } })
    self.cmd:set('host', value)
    return self
end

--- Sets `--key-from-stdin`
--- @return distant.core.builder.server.ListenCmdBuilder
function M:set_key_from_stdin()
    self.cmd:set('key-from-stdin')
    return self
end

--- Sets `--log-file <value>`
--- @param value string
--- @return distant.core.builder.server.ListenCmdBuilder
function M:set_log_file(value)
    vim.validate({ value = { value, 'string' } })
    self.cmd:set('log-file', value)
    return self
end

--- Sets `--log-level <value>`
--- @param value distant.core.log.Level
--- @return distant.core.builder.server.ListenCmdBuilder
function M:set_log_level(value)
    vim.validate({ value = { value, 'string' } })
    self.cmd:set('log-level', value)
    return self
end

--- Sets `--port <value>[:n]`
--- @param value number
--- @param n? number #if provided, tries a range of ports from <value> to <n>
--- @return distant.core.builder.server.ListenCmdBuilder
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
--- @return distant.core.builder.server.ListenCmdBuilder
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
--- @return distant.core.builder.server.ListenCmdBuilder
function M:set_timeout(value)
    vim.validate({ value = { value, 'number' } })
    self.cmd:set('timeout', tostring(value))
    return self
end

--- Sets `--use-ipv6`
--- @return distant.core.builder.server.ListenCmdBuilder
function M:set_use_ipv6()
    self.cmd:set('use-ipv6')
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
