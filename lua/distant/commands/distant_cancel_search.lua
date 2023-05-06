local editor = require('distant.editor')
local utils = require('distant.commands.utils')

--- DistantCancelSearch
--- @param cmd NvimCommand
local function command(cmd)
    local input = utils.parse_input(cmd.args)
    utils.paths_to_number(input.opts, { 'timeout', 'interval' })

    editor.cancel_search()
end

--- @type DistantCommand
local COMMAND = {
    name        = 'DistantCancelSearch',
    description = 'Cancels the active search being performed on the remote machine',
    command     = command,
    bang        = false,
    nargs       = 0,
}
return COMMAND
