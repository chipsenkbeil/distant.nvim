local editor = require('distant.editor')
local utils = require('distant.commands.utils')

--- DistantOpen path [opt1=... opt2=...]
--- @param cmd NvimCommand
local function command(cmd)
    local input = utils.parse_args(cmd.args)
    utils.paths_to_number(input.opts, { 'buf', 'win' })

    local path = input.args[1]
    input.opts.path = path

    -- TODO: Support bang! to force-reload a file, and
    --       by default not reload it if there are
    --       unsaved changes
    editor.open(input.opts)
end

--- @type DistantCommand
local COMMAND = {
    name        = 'DistantOpen',
    description = 'Open a file or directory on the remote machine',
    command     = command,
    bang        = true,
    nargs       = '*',
}
return COMMAND
