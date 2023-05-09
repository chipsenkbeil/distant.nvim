local M = {}

local function hl(highlight)
    return function(text)
        return { text, highlight }
    end
end

-- aliases
M.none                           = hl('')
M.header                         = hl('DistantHeader')
M.header_secondary               = hl('DistantHeaderSecondary')
M.muted                          = hl('DistantMuted')
M.muted_block                    = hl('DistantMutedBlock')
M.muted_block_bold               = hl('DistantMutedBlockBold')
M.highlight                      = hl('DistantHighlight')
M.highlight_block                = hl('DistantHighlightBlock')
M.highlight_block_bold           = hl('DistantHighlightBlockBold')
M.highlight_block_secondary      = hl('DistantHighlightBlockSecondary')
M.highlight_block_bold_secondary = hl('DistantHighlightBlockBoldSecondary')
M.highlight_secondary            = hl('DistantHighlightSecondary')
M.error                          = hl('DistantError')
M.warning                        = hl('DistantWarning')
M.heading                        = hl('DistantHeading')

setmetatable(M, {
    __index = function(self, key)
        self[key] = hl(key)
        return self[key]
    end,
})

return M
