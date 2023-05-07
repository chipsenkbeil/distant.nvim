local fn    = require('distant.fn')
local utils = require('distant.commands.utils')

--- DistantMkdir path [opt1=... opt2=...]
--- @param cmd NvimCommand
local function command(cmd)
    local input = utils.parse_input(cmd.args)
    utils.paths_to_number(input.opts, { 'timeout', 'interval' })

    local path = input.args[1]
    input.opts.path = path

    local opts = input.opts

    --- @cast opts -table, +distant.client.api.CreateDirOpts
    local err, _ = fn.create_dir(opts)
    assert(not err, err)
end

--- @type DistantCommand
local COMMAND = {
    name        = 'DistantMkdir',
    description = 'Creates a new directory on the remote machine',
    command     = command,
    bang        = false,
    nargs       = '*',
}
return COMMAND
