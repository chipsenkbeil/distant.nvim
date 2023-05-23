local consts = require('distant.ui.windows.main.constants')
local plugin = require('distant')
local Window = require('distant-core.ui').Window

local WINOPTS = {
    border       = 'none',
    winhighlight = { 'NormalFloat:DistantNormal' },
}

--- @class distant.plugin.ui.windows.MainWindow: distant.core.ui.Window
local window = Window:new({
    name          = 'distant.nvim',
    filetype      = 'distant-window',
    view          = require('distant.ui.windows.main.view'),
    initial_state = require('distant.ui.windows.main.state'),
    effects       = require('distant.ui.windows.main.effects'),
    winopts       = WINOPTS,
})

plugin:on('connection:changed', function()
    window:dispatch(consts.EFFECTS.RELOAD_TAB, {
        tab = { consts.VIEW.CONNECTIONS, consts.VIEW.SYSTEM_INFO },
        force = true,
    })
end)

--- Changes the view of the window.
--- @param view distant.plugin.ui.windows.main.View
function window:set_view(view)
    self:dispatch(consts.EFFECTS.SET_VIEW, view)
end

--- Returns the current view of the window.
--- @return distant.plugin.ui.windows.main.View
function window:get_view()
    --- @type distant.plugin.ui.windows.main.State
    local state = window:get_state()
    return state.view.current
end

return window
