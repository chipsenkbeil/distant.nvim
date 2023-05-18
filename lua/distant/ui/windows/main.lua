local plugin = require('distant')
local Window = require('distant-core.ui').Window

local window = Window:new({
    name = 'distant.nvim',
    filetype = 'distant',
    view = require('distant.ui.windows.main.view'),
    initial_state = require('distant.ui.windows.main.state'),
    effects = require('distant.ui.windows.main.effects'),
    winopts = {
        border = 'none',
        winhighlight = {
            'NormalFloat:DistantNormal',
        },
    },
})

plugin:on('connection:changed', function()
    window:dispatch('RELOAD_TAB', {
        tab = { 'Connections', 'System Info' },
        force = true,
    })
end)

return window
