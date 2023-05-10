local Ui = require('distant.ui')

--- DistantSystemInfo
--- @param cmd NvimCommand
--- @diagnostic disable-next-line:unused-local
local function command(cmd)
    Ui.set_view('System Info')
    Ui.open()
end

--- @type DistantCommand
local COMMAND = {
    name        = 'DistantSystemInfo',
    description = 'Display information about the system of the remote server',
    command     = command,
    bang        = false,
    nargs       = 0,
}
return COMMAND
