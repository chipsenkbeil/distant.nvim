local keymap = require('distant.ui.windows.main.keymap')
local p      = require('distant.ui.palette')
local plugin = require('distant')
local ui     = require('distant-core.ui')

local unpack = unpack or table.unpack

--- @return distant.core.ui.Span
local function version_span()
    local is_prerelease = plugin.version.plugin:has_prerelease()
    local text = ' (' .. plugin.version.plugin:as_string() .. ')'

    if is_prerelease then
        return p.warning(text)
    else
        return p.Comment(text)
    end
end

---@param state distant.plugin.ui.windows.main.State
return function(state)
    local help_key = keymap.help_key_spans

    return ui.CascadingStyleNode({ 'CENTERED' }, {
        ui.HlTextNode {
            ui.When(state.view.help.active, {
                p.none '             ',
                p.header_secondary(' ' .. state.header.title_prefix .. ' distant.nvim '),
                version_span(),
                p.none((' '):rep(#state.header.title_prefix + 1)),
            }, {
                p.none '             ',
                p.header ' distant.nvim ',
                version_span(),
            }),
            ui.When(
                state.view.help.active,
                { p.none '        press ', unpack(help_key(p.highlight_secondary, p.none(' / '))),
                    p.none ' for connections' },
                { p.none 'press ', unpack(help_key(p.highlight, p.none(' / '))), p.none ' for help' }
            ),
            { p.Comment 'https://github.com/chipsenkbeil/distant.nvim' },
            {
                p.Comment 'Give usage feedback: https://github.com/chipsenkbeil/distant.nvim/discussions/new?category=ideas',
            },
        },
    })
end
