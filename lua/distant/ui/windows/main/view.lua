local plugin  = require('distant')
local ui      = require('distant-core.ui')

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
    add(keymaps.exit, 'CLOSE_WINDOW', nil)
    add(keymaps.main.tabs.refresh, 'RELOAD_TAB', { tab = state.view.current, force = true })

    -- Navigation tied to tabs
    add(keymaps.main.tabs.goto_connections, 'SET_VIEW', 'Connections')
    add(keymaps.main.tabs.goto_system_info, 'SET_VIEW', 'System Info')
    add(keymaps.main.tabs.goto_help, 'SET_VIEW', 'Help')

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
