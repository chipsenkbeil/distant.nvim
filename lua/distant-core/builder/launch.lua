local Cmd = require('distant-core.builder.cmd')

--- @class DistantLaunchCmdBuilder
--- @field cmd DistantCmdBuilder
local M = {}
M.__index = M

--- Creates new `launch` cmd
--- @param destination string
--- @return DistantLaunchCmdBuilder
function M:new(destination)
    local instance = {}
    setmetatable(instance, M)

    instance.cmd = Cmd:new('launch ' .. destination, {
        allowed = {
            'config',
            'cache',
            'distant',
            'distant-args',
            'distant-bind-server',
            'format',
            'log-file',
            'log-level',
            'no-shell',
            'options',
            'unix-socket',
            'windows-pipe',
        }
    })

    return instance
end

--- Sets `--config <path>`
--- @param path string
--- @return DistantLaunchCmdBuilder
function M:set_config(path)
    vim.validate({ path = { path, 'string' } })
    self.cmd:set('config', path)
    return self
end

--- Sets `--cache <path>`
--- @param path string
--- @return DistantLaunchCmdBuilder
function M:set_cache(path)
    vim.validate({ path = { path, 'string' } })
    self.cmd:set('cache', path)
    return self
end

--- Sets `--distant <value>`
--- @param value string
--- @return DistantLaunchCmdBuilder
function M:set_distant(value)
    vim.validate({ value = { value, 'string' } })
    self.cmd:set('distant', value)
    return self
end

--- Sets `--distant-args "<value> <sep> <by> <space>"`
--- @param value string|string[] #if a string, will put verbatim as value. If list of strings, will place separated by space. If inherits Baseargs, will call __tostring and insert
--- @return DistantLaunchCmdBuilder
function M:set_distant_args(value)
    local svalue
    if type(value) == 'table' then
        svalue = table.concat(value, ' ')
    else
        svalue = tostring(value)
    end

    self.cmd:set('distant-args', svalue)
    return self
end

--- Sets `--distant-bind-server <value>`
--- @param value 'ssh'|'any'|string
--- @return DistantLaunchCmdBuilder
function M:set_distant_bind_server(value)
    vim.validate({ value = { value, 'string' } })
    self.cmd:set('distant-bind-server', value)
    return self
end

--- Sets `--format <value>`
--- @param value 'json'|'shell'
--- @return DistantLaunchCmdBuilder
function M:set_format(value)
    vim.validate({ value = { value, 'string' } })
    self.cmd:set('format', value)
    return self
end

--- Sets `--log-file <value>`
--- @param value string
--- @return DistantLaunchCmdBuilder
function M:set_log_file(value)
    vim.validate({ value = { value, 'string' } })
    self.cmd:set('log-file', value)
    return self
end

--- Sets `--log-level <value>`
--- @param value 'off'|'error'|'warn'|'info'|'debug'|'trace'
--- @return DistantLaunchCmdBuilder
function M:set_log_level(value)
    vim.validate({ value = { value, 'string' } })
    self.cmd:set('log-level', value)
    return self
end

--- Sets `--no-shell`
--- @return DistantLaunchCmdBuilder
function M:set_no_shell()
    self.cmd:set('no-shell')
    return self
end

--- Sets `--options <options>`
--- @param options string
--- @return DistantLaunchCmdBuilder
function M:set_options(options)
    vim.validate({ options = { options, 'string' } })
    self.cmd:set('options', options)
    return self
end

--- Sets `--unix-socket <path>`
--- @param path string
--- @return DistantLaunchCmdBuilder
function M:set_unix_socket(path)
    vim.validate({ path = { path, 'string' } })
    self.cmd:set('unix-socket', path)
    return self
end

--- Sets `--windows-pipe <name>`
--- @param name string
--- @return DistantLaunchCmdBuilder
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
