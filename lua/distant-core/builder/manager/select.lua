local CmdBuilder = require('distant-core.builder.cmd')

--- @class distant.builder.manager.SelectCmdBuilder
--- @field cmd distant.builder.CmdBuilder
local M = {}
M.__index = M

--- Creates new `manager select` cmd
--- @param connection? string #optional connection id to select
--- @return distant.builder.manager.SelectCmdBuilder
function M:new(connection)
    local instance = {}
    setmetatable(instance, M)

    -- Build command and add on the optional connection id
    local cmd = 'manager select'
    if connection then
        cmd = cmd .. ' ' .. connection
    end

    instance.cmd = CmdBuilder:new(cmd, {
        allowed = {
            'config',
            'cache',
            'format',
            'log-file',
            'log-level',
            'unix-socket',
            'windows-pipe',
        }
    })

    return instance
end

--- Sets multiple arguments using the given table.
--- @param tbl table<string, boolean|string>
--- @return distant.builder.manager.SelectCmdBuilder
function M:set_from_tbl(tbl)
    self.cmd:set_from_tbl(tbl)
    return self
end

--- Sets `--config <path>`
--- @param path string
--- @return distant.builder.manager.SelectCmdBuilder
function M:set_config(path)
    vim.validate({ path = { path, 'string' } })
    self.cmd:set('config', path)
    return self
end

--- Sets `--cache <path>`
--- @param path string
--- @return distant.builder.manager.SelectCmdBuilder
function M:set_cache(path)
    vim.validate({ path = { path, 'string' } })
    self.cmd:set('cache', path)
    return self
end

--- Sets `--format <format>`
--- @param format 'json'|'shell'
--- @return distant.builder.manager.SelectCmdBuilder
function M:set_format(format)
    vim.validate({ format = { format, 'string' } })
    self.cmd:set('format', format)
    return self
end

--- Sets `--log-file <value>`
--- @param value string
--- @return distant.builder.manager.SelectCmdBuilder
function M:set_log_file(value)
    vim.validate({ value = { value, 'string' } })
    self.cmd:set('log-file', value)
    return self
end

--- Sets `--log-level <value>`
--- @param value distant.core.log.Level
--- @return distant.builder.manager.SelectCmdBuilder
function M:set_log_level(value)
    vim.validate({ value = { value, 'string' } })
    self.cmd:set('log-level', value)
    return self
end

--- Sets `--unix-socket <path>`
--- @param path string
--- @return distant.builder.manager.SelectCmdBuilder
function M:set_unix_socket(path)
    vim.validate({ path = { path, 'string' } })
    self.cmd:set('unix-socket', path)
    return self
end

--- Sets `--windows-pipe <name>`
--- @param name string
--- @return distant.builder.manager.SelectCmdBuilder
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
