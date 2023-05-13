local ui = require('distant.ui')

--- Distant
--- @param cmd NvimCommand
--- @diagnostic disable-next-line:unused-local
local function command(cmd)
    ui.open()
end

--- @type DistantCommand
local COMMAND = {
    name        = 'Distant',
    description = 'Open the distant user interface',
    command     = command,
    bang        = false,
    nargs       = 0,
}
return COMMAND
