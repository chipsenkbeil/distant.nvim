local keymap = require('distant.ui.keymap')
local p      = require('distant.ui.palette')
local plugin = require('distant')
local ui     = require('distant-core.ui')

--- Creates a series of spans that represent a tab visually.
--- @param text string
--- @param keymap string
--- @param is_active boolean
--- @return distant.core.ui.Span[]
local function create_tab_span(text, keymap, is_active)
    if is_active then
        return {
            p.highlight_block_bold(' '),
            p.highlight_block_bold(' ' .. text .. ' '),
            p.highlight_block_bold('(' .. keymap .. ')'),
            p.none(' '),
        }
    else
        return {
            p.muted_block(' '),
            p.muted_block(' ' .. text .. ' '),
            p.muted_block('(' .. keymap .. ')'),
            p.none(' '),
        }
    end
end

--- @param state distant.plugin.ui.windows.main.State
--- @return distant.core.ui.CascadingStyleNode
return function(state)
    --- Represents all of the spans representing all of the tabs on a line
    --- @type distant.core.ui.Span[]
    local tabs = {}

    local function add(name, keymap)
        --- @diagnostic disable-next-line:missing-parameter
        vim.list_extend(
            tabs,
            create_tab_span(name, keymap, state.view.current == name)
        )
    end

    add('Connections', plugin.settings.keymap.ui.main.tabs.goto_connections)
    add('System Info', plugin.settings.keymap.ui.main.tabs.goto_system_info)
    add('Help', plugin.settings.keymap.ui.main.tabs.goto_help)

    return ui.CascadingStyleNode({ 'INDENT' }, {
        ui.HlTextNode({ tabs }),
        ui.StickyCursor({ id = 'tabs' }),
    })
end
