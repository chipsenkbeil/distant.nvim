local ui = require('distant.ui')

--- DistantSessionInfo
--- @param cmd NvimCommand
--- @diagnostic disable-next-line:unused-local
local function command(cmd)
    ui.set_view('Connections')
    ui.open()
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
