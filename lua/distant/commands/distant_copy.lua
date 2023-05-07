local fn    = require('distant.fn')
local utils = require('distant.commands.utils')

--- DistantCopy src dst [opt1=... opt2=...]
--- @param cmd NvimCommand
local function command(cmd)
    local input = utils.parse_input(cmd.args)
    utils.paths_to_number(input.opts, { 'timeout', 'interval' })

    local src = input.args[1]
    local dst = input.args[2]
    input.opts.src = src
    input.opts.dst = dst

    local opts = input.opts

    --- @cast opts -table, +distant.client.api.CopyOpts
    local err, _ = fn.copy(opts)
    assert(not err, tostring(err))
end

--- @type DistantCommand
local COMMAND = {
    name        = 'DistantCopy',
    description = 'Copies a file or directory from src to dst on the remote machine',
    command     = command,
    bang        = false,
    nargs       = '*',
}
return COMMAND
