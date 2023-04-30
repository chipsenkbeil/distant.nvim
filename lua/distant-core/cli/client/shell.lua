local builder = require('distant-core.builder')

--- Represents a distant client shell
--- @class ClientShell
--- @field config ClientConfig
local M = {}
M.__index = M

--- Creates a new instance of distant client shell
--- @param opts ClientConfig
--- @return ClientShell
function M:new(opts)
    opts = opts or {}

    local instance = {}
    setmetatable(instance, M)
    instance.config = opts
    assert(instance.config.binary, 'Shell missing binary')
    assert(instance.config.network, 'Shell missing network')

    return instance
end

--- @class ClientShellSpawnOpts
--- @field cmd? string|string[] #Optional command to use instead of default shell
--- @field buf? number #Optional buffer to assign to shell, defaulting to current buffer
--- @field win? number #Optional window to assign to shell, default to current window

--- @param opts ClientShellSpawnOpts
--- @return number #Job id, or 0 if invalid arguments or -1 if cli is not executable
function M:spawn(opts)
    -- Acquire a command list that we will execute in our terminal
    local cmd = builder
        .shell(opts.cmd)
        :set_from_tbl(self.config)
        :as_list()

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

return M
