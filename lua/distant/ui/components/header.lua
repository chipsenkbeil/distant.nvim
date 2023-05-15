local ui = require('distant-core.ui')
local p = require('distant.ui.palette')
local plugin = require('distant')

--- @return distant.core.ui.HlTextNode
local function version_node()
    local is_prerelease = plugin.version.plugin:is_prerelease()
    local text = ' (' .. plugin.version.plugin:as_string() .. ')'

    if is_prerelease then
        return p.warning(text)
    else
        return p.Comment(text)
    end
end

---@param state distant.ui.State
return function(state)
    return ui.CascadingStyleNode({ 'CENTERED' }, {
        ui.HlTextNode {
            ui.When(state.view.help.active, {
                p.none '             ',
                p.header_secondary(' ' .. state.header.title_prefix .. ' distant.nvim '),
                version_node(),
                p.none((' '):rep(#state.header.title_prefix + 1)),
            }, {
                p.none '             ',
                p.header ' distant.nvim ',
                version_node(),
            }),
            ui.When(
                state.view.help.active,
                { p.none '        press ', p.highlight_secondary '?', p.none ' for connections' },
                { p.none 'press ', p.highlight '?', p.none ' for help' }
            ),
            { p.Comment 'https://github.com/chipsenkbeil/distant.nvim' },
            {
                p.Comment 'Give usage feedback: https://github.com/chipsenkbeil/distant.nvim/discussions/new?category=ideas',
            },
        },
    })
end
