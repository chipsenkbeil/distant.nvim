local plugin = require('distant')
local utils = require('distant.commands.utils')

--- DistantShell [cmd arg1 arg2 ...]
--- @param cmd NvimCommand
local function command(cmd)
    local input = utils.parse_args(cmd.args)
    utils.paths_to_number(input.opts, { 'timeout', 'interval' })

    --- @diagnostic disable-next-line:redefined-local
    local cmd = nil
    local cmd_prog = nil
    if not vim.tbl_isempty(input.args) then
        cmd_prog = input.args[1]
        cmd = vim.list_slice(input.args, 2, #input.args)
        table.insert(cmd, 1, cmd_prog)
    end

    -- Spawn a shell in a new buffer, taking over the current window
    plugin:spawn_shell({ cmd = cmd })
end

--- @type DistantCommand
local COMMAND = {
    name        = 'DistantShell',
    description = 'Spawns a remote shell for the current connection',
    command     = command,
    bang        = false,
    nargs       = '*',
}
return COMMAND
