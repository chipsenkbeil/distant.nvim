local Ui = require 'distant-core.ui'
local p = require 'distant.ui.palette'

--- Creates a series of spans that represent a tab visually.
--- @param text string
--- @param index integer
--- @param is_active boolean
--- @param use_secondary_highlight boolean
--- @return distant.core.ui.Span[]
local function create_tab_span(text, index, is_active, use_secondary_highlight)
    local highlight_block = use_secondary_highlight and p.highlight_block_bold_secondary or p.highlight_block_bold

    if is_active then
        return {
            highlight_block(' '),
            highlight_block('(' .. index .. ')'),
            highlight_block(' ' .. text .. ' '),
            p.none(' '),
        }
    else
        return {
            p.muted_block(' '),
            p.muted_block('(' .. index .. ')'),
            p.muted_block(' ' .. text .. ' '),
            p.none(' '),
        }
    end
end

--- @param state distant.ui.State
--- @return distant.core.ui.CascadingStyleNode
return function(state)
    --- Represents all of the spans representing all of the tabs on a line
    --- @type distant.core.ui.Span[]
    local tabs = {}

    for i, text in ipairs { 'Connections', 'System Info' } do
        --- @diagnostic disable-next-line:missing-parameter
        vim.list_extend(
            tabs,
            create_tab_span(text, i, state.view.current == text, state.view.is_showing_help)
        )
    end
    return Ui.CascadingStyleNode({ 'INDENT' }, {
        Ui.HlTextNode({ tabs }),
        Ui.StickyCursor({ id = 'tabs' }),
    })
end
