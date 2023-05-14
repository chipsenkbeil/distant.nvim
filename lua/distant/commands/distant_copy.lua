local plugin = require('distant')
local utils  = require('distant.commands.utils')

--- DistantCopy src dst [opt1=... opt2=...]
--- @param cmd NvimCommand
local function command(cmd)
    local input = utils.parse_args(cmd.args)
    utils.paths_to_number(input.opts, { 'timeout', 'interval' })

    local src = input.args[1]
    local dst = input.args[2]
    input.opts.src = src
    input.opts.dst = dst

    local opts = input.opts

    -- Copy file using the active client
    --- @cast opts -table, +distant.core.api.CopyOpts
    local err, _ = plugin.api.copy(opts)
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
