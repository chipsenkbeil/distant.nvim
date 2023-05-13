local plugin = require('distant')
local utils  = require('distant.commands.utils')

--- DistantSpawn cmd [arg1 arg2 ...]
--- @param cmd NvimCommand
local function command(cmd)
    local input = utils.parse_args(cmd.args)
    utils.paths_to_number(input.opts, { 'timeout', 'interval' })

    --- @diagnostic disable-next-line:redefined-local
    local cmd = input.args[1]
    local cmd_args = vim.list_slice(input.args, 2, #input.args)
    local opts = {
        cmd = cmd,
        args = cmd_args,
    }

    -- TODO: Use explicit client id from buffer!
    local err, res = plugin.api.spawn(opts)
    assert(not err, tostring(err))

    --- @cast res -distant.core.api.Process
    assert(res, 'Missing results of process execution')

    if #res.stdout > 0 then
        print(string.char(table.unpack(res.stdout)))
    end

    if #res.stderr > 0 then
        vim.api.nvim_err_writeln(string.char(table.unpack(res.stderr)))
    end
end

--- @type DistantCommand
local COMMAND = {
    name        = 'DistantSpawn',
    aliases     = { 'DistantRun' },
    description = 'Executes a remote command, returning the results',
    command     = command,
    bang        = false,
    nargs       = '*',
}
return COMMAND
