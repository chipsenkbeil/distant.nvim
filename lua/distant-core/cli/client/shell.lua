local Cmd = require('distant-core.cli.cmd')

--- Represents a distant client shell
--- @class ClientShell
--- @field config ClientConfig
local ClientShell = {}
ClientShell.__index = ClientShell

--- Creates a new instance of distant client shell
--- @param opts ClientConfig
--- @return ClientShell
function ClientShell:new(opts)
    opts = opts or {}

    local instance = {}
    setmetatable(instance, ClientShell)
    instance.config = opts
    assert(instance.config.binary, 'Shell missing binary')
    assert(instance.config.network, 'Shell missing network')

    return instance
end

--- @class ClientShellSpawnOpts
--- @field cmd string|string[]|nil #Optional command to use instead of default shell
--- @field buf number|nil #Optional buffer to assign to shell, defaulting to current buffer
--- @field win number|nil #Optional window to assign to shell, default to current window

--- @param opts ClientShellSpawnOpts
--- @return number #Job id, or 0 if invalid arguments or -1 if cli is not executable
function ClientShell:spawn(opts)
    -- Acquire a command list that we will execute in our terminal
    local cmd = self:to_cmd(opts or {})

    -- Get or create the buffer we will be using with this terminal,
    -- ensure it is no longer modifiable, switch to it, and then
    -- spawn the remote shell
    local buf = opts.buf
    if buf == nil or buf == -1 then
        buf = vim.api.nvim_create_buf(true, false)
        assert(buf ~= 0, 'Failed to create buffer for remote shell')
    end
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    vim.api.nvim_win_set_buf(opts.win or 0, buf)

    local job_id = vim.fn.termopen(cmd)

    if job_id == 0 then
        error('Invalid arguments: ' .. table.concat(cmd or {}, ' '))
    elseif job_id == -1 then
        error(self.config.binary .. ' is not executable')
    end

    return job_id
end

--- @class ClientShellToCmdOpts
--- @field cmd string|string[]|nil #Optional command to use instead of default shell

--- @param opts ClientShellToCmdOpts
--- @return string[] #list representing the command separated by whitespace
function ClientShell:to_cmd(opts)
    local c = (opts or {}).cmd
    local is_table = type(c) == 'table'
    local is_string = type(c) == 'string'
    if (is_table and vim.tbl_isempty(c)) or (is_string and vim.trim(c) == '') then
        c = nil
    elseif is_table then
        c = table.concat(c, ' ')
    end

    --- @type string[]
    local cmd = Cmd.client.shell(c):set_from_tbl(self.config.network):as_list()
    table.insert(cmd, 1, self.config.binary)

    return cmd
end

return ClientShell
