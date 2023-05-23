local plugin  = require('distant')
local ui      = require('distant-core.ui')

local consts  = require('distant.ui.windows.main.constants')
local Content = require('distant.ui.windows.main.view.content')
local Footer  = require('distant.ui.windows.main.view.footer')
local Header  = require('distant.ui.windows.main.view.header')
local Tabs    = require('distant.ui.windows.main.view.tabs')

--- @param state distant.plugin.ui.windows.main.State
--- @return distant.core.ui.Node
local function GlobalKeybinds(state)
    local keybindings = {}

    --- @param keymap distant.plugin.settings.Keymap
    --- @param effect string
    --- @param payload any
    local function add(keymap, effect, payload)
        local keymaps = keymap

        if type(keymaps) == 'string' then
            keymaps = { keymaps }
        end

        for _, lhs in ipairs(keymaps) do
            table.insert(keybindings, ui.Keybind(lhs, effect, payload, true))
        end
    end

    local keymaps = plugin.settings.keymap.ui

    -- General window actions
    add(keymaps.exit, consts.EFFECTS.CLOSE_WINDOW, nil)
    add(keymaps.main.tabs.refresh, consts.EFFECTS.RELOAD_TAB, { tab = state.view.current, force = true })

    -- Navigation tied to tabs
    add(keymaps.main.tabs.goto_connections, consts.EFFECTS.SET_VIEW, 'Connections')
    add(keymaps.main.tabs.goto_system_info, consts.EFFECTS.SET_VIEW, 'System Info')
    add(keymaps.main.tabs.goto_help, consts.EFFECTS.SET_VIEW, 'Help')

    return ui.Node(keybindings)
end

--- @param state distant.plugin.ui.windows.main.State
--- @return distant.core.ui.INode
return function(state)
    return ui.Node {
        GlobalKeybinds(state),
        Header(state),
        Tabs(state),
        Content(state),
        Footer(state),
    }
end
