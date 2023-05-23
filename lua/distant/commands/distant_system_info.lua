local consts = require('distant.ui.windows.main.constants')
local window = require('distant.ui.windows.main')

--- DistantSystemInfo
--- @param cmd NvimCommand
--- @diagnostic disable-next-line:unused-local
local function command(cmd)
    window:open()

    -- NOTE: Setting the view only works after the window is opened once
    --       as we do not initialize our effects until that happens!
    window:set_view(consts.VIEW.SYSTEM_INFO)
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
