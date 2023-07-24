local plugin = require('distant')
local utils  = require('distant.commands.utils')

--- DistantMetadata path [opt1=... opt2=...]
--- @param cmd NvimCommand
local function command(cmd)
    local input = utils.parse_args(cmd.args)
    utils.paths_to_number(input.opts, { 'timeout', 'interval' })
    utils.paths_to_bool(input.opts, { 'canonicalize', 'resolve_file_type' })

    local path = input.args[1]
    input.opts.path = path

    plugin.editor.show_metadata(input.opts)
end

--- @type DistantCommand
local COMMAND = {
    name        = 'DistantMetadata',
    description = 'Display metadata for specified path on remote machine',
    command     = command,
    bang        = false,
    nargs       = '*',
}
return COMMAND
