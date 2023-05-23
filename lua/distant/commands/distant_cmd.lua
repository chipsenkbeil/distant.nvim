local consts = require('distant.ui.windows.main.constants')
local window = require('distant.ui.windows.main')

--- Distant
--- @param cmd NvimCommand
--- @diagnostic disable-next-line:unused-local
local function command(cmd)
    window:open()

    -- Atempt to load our connections and system
    -- information the first time we open the window
    --
    -- NOTE: Must be invoked after opening window
    --       as the effect handlers aren't set
    --       until after it is opened!
    window:dispatch(consts.EFFECTS.RELOAD_TAB, {
        tab = { consts.VIEW.CONNECTIONS, consts.VIEW.SYSTEM_INFO },
        force = false,
    })
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
