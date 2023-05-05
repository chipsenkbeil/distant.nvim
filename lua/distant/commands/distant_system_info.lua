local editor = require('distant.editor')

--- DistantSystemInfo
--- @param cmd NvimCommand
--- @diagnostic disable-next-line:unused-local
local function command(cmd)
    editor.show_system_info()
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
