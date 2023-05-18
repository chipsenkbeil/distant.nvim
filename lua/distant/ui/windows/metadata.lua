local Window = require('distant-core.ui').Window

return Window:new({
    name = 'Metadata',
    filetype = 'distant',
    view = require('distant.ui.windows.metadata.view'),
    initial_state = require('distant.ui.windows.metadata.state'),
    effects = require('distant.ui.windows.metadata.effects'),
    winopts = {
        border = 'single',
        winhighlight = { 'NormalFloat:DistantNormal' },
        width = 0.4,
        height = 0.3,
    },
})
