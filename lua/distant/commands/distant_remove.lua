local plugin = require('distant')
local utils  = require('distant.commands.utils')

--- DistantRemove path [opt1=... opt2=...]
--- @param cmd NvimCommand
local function command(cmd)
    local input = utils.parse_args(cmd.args)
    utils.paths_to_number(input.opts, { 'timeout', 'interval' })

    local path = input.args[1]

    -- Remove file using the active client
    local err, _ = plugin.api.remove({
        path = path,
        force = cmd.bang == true,
        timeout = tonumber(input.opts.timeout),
        interval = tonumber(input.opts.interval),
    })
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
