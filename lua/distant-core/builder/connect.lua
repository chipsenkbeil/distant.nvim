local CmdBuilder = require('distant-core.builder.cmd')

--- @class distant.core.builder.ConnectCmdBuilder
--- @field cmd distant.core.builder.CmdBuilder
local M = {}
M.__index = M

--- Creates new `connect` cmd
--- @param destination string
--- @return distant.core.builder.ConnectCmdBuilder
function M:new(destination)
    local instance = {}
    setmetatable(instance, M)

    instance.cmd = CmdBuilder:new('connect ' .. destination, {
        allowed = {
            'config',
            'cache',
            'format',
            'log-file',
            'log-level',
            'options',
            'unix-socket',
            'windows-pipe',
        }
    })

    return instance
end

--- Sets multiple arguments using the given table.
--- @param tbl table<string, boolean|string>
--- @return distant.core.builder.ConnectCmdBuilder
function M:set_from_tbl(tbl)
    self.cmd:set_from_tbl(tbl)
    return self
end

--- Sets `--config <path>`
--- @param path string
--- @return distant.core.builder.ConnectCmdBuilder
function M:set_config(path)
    vim.validate({ path = { path, 'string' } })
    self.cmd:set('config', path)
    return self
end

--- Sets `--cache <path>`
--- @param path string
--- @return distant.core.builder.ConnectCmdBuilder
function M:set_cache(path)
    vim.validate({ path = { path, 'string' } })
    self.cmd:set('cache', path)
    return self
end

--- Sets `--format <format>`
--- @param format distant.core.builder.Format
--- @return distant.core.builder.ConnectCmdBuilder
function M:set_format(format)
    vim.validate({ format = { format, 'string' } })
    self.cmd:set('format', format)
    return self
end

--- Sets `--log-file <value>`
--- @param value string
--- @return distant.core.builder.ConnectCmdBuilder
function M:set_log_file(value)
    vim.validate({ value = { value, 'string' } })
    self.cmd:set('log-file', value)
    return self
end

--- Sets `--log-level <value>`
--- @param value distant.core.log.Level
--- @return distant.core.builder.ConnectCmdBuilder
function M:set_log_level(value)
    vim.validate({ value = { value, 'string' } })
    self.cmd:set('log-level', value)
    return self
end

--- Sets `--options <options>`
--- @param options string
--- @return distant.core.builder.ConnectCmdBuilder
function M:set_options(options)
    vim.validate({ options = { options, 'string' } })
    self.cmd:set('options', options)
    return self
end

--- Sets `--unix-socket <path>`
--- @param path string
--- @return distant.core.builder.ConnectCmdBuilder
function M:set_unix_socket(path)
    vim.validate({ path = { path, 'string' } })
    self.cmd:set('unix-socket', path)
    return self
end

--- Sets `--windows-pipe <name>`
--- @param name string
--- @return distant.core.builder.ConnectCmdBuilder
function M:set_windows_pipe(name)
    vim.validate({ name = { name, 'string' } })
    self.cmd:set('windows-pipe', name)
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
