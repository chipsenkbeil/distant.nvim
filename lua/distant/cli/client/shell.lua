local cli = require('distant.cli')
local Cmd = require('distant.cli.cmd')

local shell = {}

--- @class ShellSpawnOpts
--- @field connection Connection #Connection
--- @field cmd? string|string[] #Optional command to use instead of default shell
--- @field buf? number #Optional buffer to assign to shell, defaulting to current buffer
--- @field win? number #Optional window to assign to shell, default to current window

--- @param opts ShellSpawnOpts
--- @return number #Job id, or 0 if invalid arguments or -1 if cli is not executable
function shell.spawn(opts)
    local c = opts.cmd
    local is_table = type(c) == 'table'
    local is_string = type(c) == 'string'
    if (is_table and vim.tbl_isempty(c)) or (is_string and vim.trim(c) == '') then
        c = nil
    elseif is_table then
        c = table.concat(c, ' ')
    end

    --- @type string[]
    local cmd = cli.build_cmd(
        Cmd.client.shell(c),
        { list = true }
    )

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
        local cmd_prog = c and vim.split(c, ' ', true)[1]
        if cmd_prog then
            error(cmd_prog .. ' is not executable')
        else
            error('Default shell is not executable')
        end
    end

    return job_id
end

return shell
