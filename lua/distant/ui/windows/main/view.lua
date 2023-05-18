local ui      = require('distant-core.ui')

local Content = require('distant.ui.windows.main.view.content')
local Footer  = require('distant.ui.windows.main.view.footer')
local Header  = require('distant.ui.windows.main.view.header')
local Help    = require('distant.ui.windows.main.view.help')
local Tabs    = require('distant.ui.windows.main.view.tabs')

--- @param state distant.ui.windows.main.State
--- @return distant.core.ui.Node
local function GlobalKeybinds(state)
    return ui.Node {
        ui.Keybind('?', 'TOGGLE_HELP', nil, true),
        ui.Keybind('q', 'CLOSE_WINDOW', nil, true),
        ui.Keybind('<Esc>', 'CLOSE_WINDOW', nil, true),
        ui.Keybind('r', 'RELOAD_TAB', { tab = state.view.current, force = true }, true),

        ui.Keybind('1', 'SET_VIEW', 'Connections', true),
        ui.Keybind('2', 'SET_VIEW', 'System Info', true),
    }
end

--- @param state distant.ui.windows.main.State
--- @return distant.core.ui.INode
return function(state)
    return ui.Node {
        GlobalKeybinds(state),
        Header(state),
        Tabs(state),
        ui.When(state.view.help.active, function()
            return Help(state)
        end),
        ui.When(not state.view.help.active, function()
            return Content(state)
        end),
        Footer(state),
    }
end
