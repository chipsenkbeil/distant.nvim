local Ui = require('distant-core.ui')
local p = require('distant.ui.palette')

---@param state distant.ui.State
return function(state)
    return Ui.CascadingStyleNode({ 'CENTERED' }, {
        Ui.HlTextNode {
            Ui.When(state.view.is_showing_help, {
                p.none '             ',
                p.header_secondary(' ' .. state.header.title_prefix .. ' distant.nvim '),
                p.Comment ' alpha branch',
                p.none((' '):rep(#state.header.title_prefix + 1)),
            }, {
                p.none '             ',
                p.header ' distant.nvim ',
                p.Comment ' alpha branch',
            }),
            Ui.When(
                state.view.is_showing_help,
                { p.none '        press ', p.highlight_secondary 'g?', p.none ' for connections' },
                { p.none 'press ', p.highlight 'g?', p.none ' for help' }
            ),
            { p.Comment 'https://github.com/chipsenkbeil/distant.nvim' },
            {
                p.Comment 'Give usage feedback: https://github.com/chipsenkbeil/distant.nvim/discussions/new?category=ideas',
            },
        },
    })
end
