local plugin = require('distant')

--- DistantCancelSearch
--- @param cmd NvimCommand
--- @diagnostic disable-next-line:unused-local
local function command(cmd)
    plugin.editor.cancel_search()
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
