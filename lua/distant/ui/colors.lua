local hl_groups = {
    DistantNormal = {
        link = 'NormalFloat',
        default = true,
    },
    DistantHeader = {
        bold = true,
        fg = '#222222',
        bg = '#DCA561',
        default = true,
    },
    DistantHeaderSecondary = {
        bold = true,
        fg = '#222222',
        bg = '#56B6C2',
        default = true,
    },
    DistantHighlight = {
        fg = '#56B6C2',
        default = true,
    },
    DistantHighlightBlock = {
        bg = '#56B6C2',
        fg = '#222222',
        default = true,
    },
    DistantHighlightBlockBold = {
        bg = '#56B6C2',
        fg = '#222222',
        bold = true,
        default = true,
    },
    DistantHighlightSecondary = {
        fg = '#DCA561',
        default = true,
    },
    DistantHighlightBlockSecondary = {
        bg = '#DCA561',
        fg = '#222222',
        default = true,
    },
    DistantHighlightBlockBoldSecondary = {
        bg = '#DCA561',
        fg = '#222222',
        bold = true,
        default = true,
    },
    DistantLink = {
        link = 'DistantHighlight',
        default = true,
    },
    DistantMuted = {
        fg = '#888888',
        default = true,
    },
    DistantMutedBlock = {
        bg = '#888888',
        fg = '#222222',
        default = true,
    },
    DistantMutedBlockBold = {
        bg = '#888888',
        fg = '#222222',
        bold = true,
        default = true,
    },
    DistantError = {
        link = 'ErrorMsg',
        default = true,
    },
    DistantWarning = {
        link = 'WarningMsg',
        default = true,
    },
    DistantHeading = {
        bold = true,
        default = true,
    },
}

local is_initialized = false

return {
    -- NOTE: Need to schedule wrap this, otherwise depending on when this is invoked it can not work!
    initialize = vim.schedule_wrap(function()
        if is_initialized then
            return
        end
        local log = require('distant-core').log
        log.debug('distant:initialize:ui:colors')

        for name, hl in pairs(hl_groups) do
            log.fmt_trace('distant:initialize:ui:color = %s, %s', name, hl)
            vim.api.nvim_set_hl(0, name, hl)
        end

        is_initialized = true
    end)
}
