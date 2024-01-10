local consts = require('distant.ui.windows.main.constants')
local keymap = require('distant.ui.keymap')
local log    = require('distant-core.log')
local p      = require('distant.ui.palette')
local plugin = require('distant')
local ui     = require('distant-core.ui')

local unpack = unpack or table.unpack

---@param state distant.plugin.ui.windows.main.State
return function(state)
    --- @type {[1]: string, [2]: distant.plugin.settings.Keymap}[]
    local keymap_tuples = {}

    local keymaps = plugin.settings.keymap.ui

    -- Add our globals that we want to show at the top
    table.insert(keymap_tuples, { 'Toggle help', keymaps.main.tabs.goto_help })
    table.insert(keymap_tuples, { 'Refresh tab', keymaps.main.tabs.refresh })

    -- Add our view-specific keybindings
    table.insert(keymap_tuples, { 'Toggle connection/server information', keymaps.main.connections.toggle_info })
    table.insert(keymap_tuples, { 'Kill connection', keymaps.main.connections.kill })

    -- Add our globals that we want to show at the bottom
    table.insert(keymap_tuples, { 'Close window', keymaps.exit })

    local is_current_settings_expanded = state.view.help.is_current_settings_expanded

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
                return {
                    p.muted(keymap_tuple[1]),
                    unpack(keymap.keymap_tospans(keymap_tuple[2], p.highlight)),
                }
            end, keymap_tuples)),
        },
        ui.EmptyLine(),
        ui.HlTextNode {
            {
                p.Bold(('%s Current settings'):format(is_current_settings_expanded and '↓' or '→')),
                p.highlight ' :help distant-settings',
            },
        },
        ui.Keybind('<CR>', consts.EFFECTS.TOGGLE_EXPAND_CURRENT_SETTINGS, nil),
        ui.When(is_current_settings_expanded, function()
            --- @type string[]
            --- @diagnostic disable-next-line:missing-parameter
            local settings_split_by_newline = vim.split(vim.inspect(plugin.settings), '\n')

            --- Map each line into a single, muted span
            --- @type distant.core.ui.Span[][]
            local current_settings = vim.tbl_map(function(line)
                return { p.muted(line) }
            end, settings_split_by_newline)

            return ui.HlTextNode(current_settings)
        end),
    }
end
