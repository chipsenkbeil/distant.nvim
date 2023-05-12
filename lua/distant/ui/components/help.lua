local ui = require('distant-core.ui')
local log = require('distant-core.log')
local p = require('distant.ui.palette')
local plugin_state = require('distant.state')

---@param state distant.ui.State
local function Ship(state)
    local ship_indent = { (' '):rep(state.view.ship_indentation), '' }
    -- stylua: ignore start
    local ship = {
        { ship_indent, p.muted '/^v^\\',                         p.none '         |    |    |' },
        { ship_indent, p.none '             )_)  )_)  )_)     ', p.muted '/^v^\\' },
        { ship_indent, p.muted '   ', p.muted '/^v^\\',
            p.none '    )___))___))___)\\     ',
            p.highlight_secondary(
                state.view.ship_exclamation) },
        { ship_indent, p.none '           )____)____)_____)\\\\' },
        { ship_indent, p.none '         _____|____|____|____\\\\\\__' },
        { ship_indent, p.muted '         ',                           p.none '\\                   /' },
    }
    -- stylua: ignore end
    local water = {
        { p.highlight '  ^^^^^ ^^^^^^^^  ^^^^^ ^^^^^  ^^^^^ ^^^^ <><  ' },
        { p.highlight '    ^^^^  ^^  ^^^    ^ ^^^    ^^^ <>< ^^^^     ' },
        { p.highlight '     ><> ^^^     ^^    ><> ^^     ^^    ^      ' },
    }
    if state.view.ship_indentation < 0 then
        for _, shipline in ipairs(ship) do
            local removed_chars = 0
            for _, span in ipairs(shipline) do
                local span_length = #span[1]
                local chars_to_remove = (math.abs(state.view.ship_indentation) - removed_chars)
                span[1] = string.sub(span[1], chars_to_remove + 1)
                removed_chars = removed_chars + (span_length - #span[1])
            end
        end
    end
    return ui.Node {
        ui.HlTextNode(ship),
        ui.HlTextNode(water),
    }
end

---@param state distant.ui.State
local function GenericHelp(state)
    local keymap_tuples = {
        { 'Toggle help',  'g?' },
        { 'Refresh tab',  'r' },
        { 'Close window', 'q' },
        { 'Close window', '<Esc>' },
    }

    local is_current_settings_expanded = state.view.is_current_settings_expanded

    return ui.Node {
        ui.HlTextNode {
            { p.muted 'Distant log: ', p.none(log.outfile) },
        },
        ui.EmptyLine(),
        ui.Table {
            {
                p.Bold 'Keyboard shortcuts',
            },
            unpack(vim.tbl_map(function(keymap_tuple)
                return { p.muted(keymap_tuple[1]), p.highlight(keymap_tuple[2]) }
            end, keymap_tuples)),
        },
        ui.EmptyLine(),
        ui.HlTextNode {
            {
                p.Bold(('%s Current settings'):format(is_current_settings_expanded and '↓' or '→')),
                p.highlight ' :help distant-settings',
            },
        },
        ui.Keybind('<CR>', 'TOGGLE_EXPAND_CURRENT_SETTINGS', nil),
        ui.When(is_current_settings_expanded, function()
            --- @type string[]
            --- @diagnostic disable-next-line:missing-parameter
            local settings_split_by_newline = vim.split(vim.inspect(plugin_state.settings), '\n')

            --- Map each line into a single, muted span
            --- @type distant.core.ui.Span[][]
            local current_settings = vim.tbl_map(function(line)
                return { p.muted(line) }
            end, settings_split_by_newline)

            return ui.HlTextNode(current_settings)
        end),
    }
end

---@param state distant.ui.State
return function(state)
    ---@type distant.core.ui.INode
    local heading = ui.Node {}

    return ui.CascadingStyleNode({ 'INDENT' }, {
        ui.HlTextNode(state.view.has_changed and p.none '' or p.Comment '(change view by pressing its number)'),
        heading,
        GenericHelp(state),
        ui.EmptyLine(),
        Ship(state),
        ui.EmptyLine(),
    })
end
