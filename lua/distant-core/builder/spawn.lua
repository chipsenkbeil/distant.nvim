local CmdBuilder = require('distant-core.builder.cmd')

--- @class distant.core.builder.SpawnCmdBuilder
--- @field cmd distant.core.builder.CmdBuilder
local M = {}
M.__index = M

--- Creates a new `spawn` cmd
--- @param cmd string|string[] #command to execute on the remote machine
--- @param use_cmd_arg? boolean # if true, will pass `cmd` as str via `--cmd <cmd>` instead of using `-- <cmd>`
--- @return distant.core.builder.SpawnCmdBuilder
function M:new(cmd, use_cmd_arg)
    local instance = {}
    setmetatable(instance, M)

    -- Flatten the command if provided as a list
    if type(cmd) == 'table' then
        cmd = table.concat(cmd, ' ')
    end

    instance.cmd = CmdBuilder
        :new('spawn', {
            allowed = {
                'config',
                'cache',
                'cmd',
                'connection',
                'current-dir',
                'environment',
                'log-file',
                'log-level',
                'lsp',
                'pty',
                'shell',
                'unix-socket',
                'windows-pipe',
            }
        })

    if use_cmd_arg then
        --- @cast instance distant.core.builder.SpawnCmdBuilder
        instance = instance:set_cmd(cmd)
    else
        instance.cmd = instance.cmd:set_tail(cmd)
    end

    return instance
end

--- Sets multiple arguments using the given table.
--- @param tbl table<string, boolean|string>
--- @return distant.core.builder.SpawnCmdBuilder
function M:set_from_tbl(tbl)
    self.cmd:set_from_tbl(tbl)
    return self
end

--- Sets `--config <path>`
--- @param path string
--- @return distant.core.builder.SpawnCmdBuilder
function M:set_config(path)
    vim.validate({ path = { path, 'string' } })
    self.cmd:set('config', path)
    return self
end

--- Sets `--cache <path>`
--- @param path string
--- @return distant.core.builder.SpawnCmdBuilder
function M:set_cache(path)
    vim.validate({ path = { path, 'string' } })
    self.cmd:set('cache', path)
    return self
end

--- Sets `--cmd <cmd>`
--- @param cmd string
--- @return distant.core.builder.SpawnCmdBuilder
function M:set_cmd(cmd)
    vim.validate({ cmd = { cmd, 'string' } })

    -- NOTE: Normally, when a string is set using the
    --       builder, it is NOT quoted, which means that
    --       cmd = "echo hello" would turn into
    --       `--cmd echo hello`. So, we need to provide
    --       quoting for the value.
    --
    --       To that affect, we are going to check if the
    --       trimmed command begins and ends with matching
    --       single or double quotes. If not, we wrap it in
    --       single quotes for now, unless using cmd.exe,
    --       in which case we wrap in double quotes.
    cmd = vim.trim(cmd)
    if (
            not (vim.startswith(cmd, '"') and vim.endswith(cmd, '"'))
            and not (vim.startswith(cmd, "'") and vim.endswith(cmd, "'"))
        ) then
        if vim.o.shell == 'cmd.exe' then
            cmd = '"' .. cmd:gsub('"', '""') .. '"'
        else
            cmd = "'" .. cmd:gsub("'", "'\\''") .. "'"
        end
    end

    self.cmd:set('cmd', cmd)
    return self
end

--- Sets `--connection <id>`
--- @param id string
--- @return distant.core.builder.SpawnCmdBuilder
function M:set_connection(id)
    vim.validate({ id = { id, 'string' } })
    self.cmd:set('connection', id)
    return self
end

--- Sets `--current-dir <dir>`
--- @param dir string
--- @return distant.core.builder.SpawnCmdBuilder
function M:set_current_dir(dir)
    vim.validate({ dir = { dir, 'string' } })
    self.cmd:set('current-dir', dir)
    return self
end

--- Sets `--environment <id>`
--- @param environment table<string, string>
--- @return distant.core.builder.SpawnCmdBuilder
function M:set_environment(environment)
    vim.validate({ environment = { environment, 'table' } })
    local s = ''
    for key, value in pairs(environment) do
        s = s .. key .. '="' .. value .. '",'
    end

    self.cmd:set('environment', s)
    return self
end

--- Sets `--log-file <value>`
--- @param value string
--- @return distant.core.builder.SpawnCmdBuilder
function M:set_log_file(value)
    vim.validate({ value = { value, 'string' } })
    self.cmd:set('log-file', value)
    return self
end

--- Sets `--log-level <value>`
--- @param value distant.core.log.Level
--- @return distant.core.builder.SpawnCmdBuilder
function M:set_log_level(value)
    vim.validate({ value = { value, 'string' } })
    self.cmd:set('log-level', value)
    return self
end

--- Sets `--lsp` or `--lsp <value>`
--- @param value boolean|string
--- @return distant.core.builder.SpawnCmdBuilder
function M:set_lsp(value)
    vim.validate({ value = { value, { 'boolean', 'string' } } })
    if value == true then
        self.cmd:set('lsp')
    else
        self.cmd:set('lsp', value)
    end
    return self
end

--- Sets `--pty`
--- @return distant.core.builder.SpawnCmdBuilder
function M:set_pty()
    self.cmd:set('pty')
    return self
end

--- Sets `--shell` or `--shell <path>`
--- @param value boolean|string
--- @return distant.core.builder.SpawnCmdBuilder
function M:set_shell(value)
    vim.validate({ value = { value, { 'boolean', 'string' } } })
    if value == true then
        self.cmd:set('shell')
    else
        self.cmd:set('shell', value)
    end
    return self
end

--- Sets `--unix-socket <path>`
--- @param path string
--- @return distant.core.builder.SpawnCmdBuilder
function M:set_unix_socket(path)
    vim.validate({ path = { path, 'string' } })
    self.cmd:set('unix-socket', path)
    return self
end

--- Sets `--windows-pipe <name>`
--- @param name string
--- @return distant.core.builder.SpawnCmdBuilder
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
