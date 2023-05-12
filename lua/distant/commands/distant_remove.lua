local fn    = require('distant.fn')
local utils = require('distant.commands.utils')

--- DistantRemove path [opt1=... opt2=...]
--- @param cmd NvimCommand
local function command(cmd)
    local input = utils.parse_args(cmd.args)
    utils.paths_to_number(input.opts, { 'timeout', 'interval' })

    local path = input.args[1]
    input.opts.path = path

    local opts = input.opts
    if cmd.bang then
        opts.force = true
    end

    --- @cast opts -table, +distant.core.api.RemoveOpts
    local err, _ = fn.remove(opts)
    assert(not err, tostring(err))
end

--- @type DistantCommand
local COMMAND = {
    name        = 'DistantRemove',
    description = 'Removes a file or directory on the remote machine',
    command     = command,
    bang        = true,
    nargs       = '*',
}
return COMMAND
