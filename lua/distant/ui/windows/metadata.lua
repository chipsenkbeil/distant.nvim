local Window = require('distant-core.ui').Window

local WINOPTS = {
    border       = 'single',
    height       = 0.3,
    width        = 0.4,
    winhighlight = { 'NormalFloat:DistantNormal' },
}

return Window:new({
    name          = 'Metadata',
    filetype      = 'distant-window',
    view          = require('distant.ui.windows.metadata.view'),
    initial_state = require('distant.ui.windows.metadata.state'),
    effects       = require('distant.ui.windows.metadata.effects'),
    winopts       = WINOPTS,
})
