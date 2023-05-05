local editor = require('distant.editor')

--- DistantSessionInfo
--- @param cmd NvimCommand
--- @diagnostic disable-next-line:unused-local
local function command(cmd)
    editor.show_session_info()
end

--- @type DistantCommand
local COMMAND = {
    name        = 'DistantSessionInfo',
    description = 'Display information for active connection to server',
    command     = command,
    bang        = false,
    nargs       = 0,
}
return COMMAND
