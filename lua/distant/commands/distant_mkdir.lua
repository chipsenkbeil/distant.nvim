local plugin = require('distant')
local utils  = require('distant.commands.utils')

--- DistantMkdir path [opt1=... opt2=...]
--- @param cmd NvimCommand
local function command(cmd)
    local input = utils.parse_args(cmd.args)
    utils.paths_to_number(input.opts, { 'timeout', 'interval' })
    utils.paths_to_bool(input.opts, { 'all' })

    local path = input.args[1]
    input.opts.path = path

    local opts = input.opts

    -- Make directory using the active client
    --- @cast opts -table, +distant.core.api.CreateDirOpts
    local err, _ = plugin.api.create_dir(opts)
    assert(not err, tostring(err))
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
