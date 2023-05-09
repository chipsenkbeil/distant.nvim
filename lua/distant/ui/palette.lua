--- @class distant.ui.Palette
local M = {}

--- @param highlight string
--- @return fun(text:string):distant.core.ui.Span
local function hl(highlight)
    --- @param text string
    --- @return distant.core.ui.Span
    return function(text)
        return { text, highlight }
    end
end

--- Creates a span with no highlight.
M.none = hl('')

--- Creates a span with a header highlight.
M.header = hl('DistantHeader')

--- Creates a span with a secondary header highlight.
M.header_secondary = hl('DistantHeaderSecondary')

--- Creates a span with a muted highlight.
M.muted = hl('DistantMuted')

--- Creates a span with a muted block highlight.
M.muted_block = hl('DistantMutedBlock')

--- Creates a span with a muted, bold block highlight.
M.muted_block_bold = hl('DistantMutedBlockBold')

--- Creates a span with a highlight highlight.
M.highlight = hl('DistantHighlight')

--- Creates a span with a block highlight highlight.
M.highlight_block = hl('DistantHighlightBlock')

--- Creates a span with a bold block highlight highlight.
M.highlight_block_bold = hl('DistantHighlightBlockBold')

--- Creates a span with a secondary block highlight highlight.
M.highlight_block_secondary = hl('DistantHighlightBlockSecondary')

--- Creates a span with a secondary, bold block highlight highlight.
M.highlight_block_bold_secondary = hl('DistantHighlightBlockBoldSecondary')

--- Creates a span with a secondary highlight highlight.
M.highlight_secondary = hl('DistantHighlightSecondary')

--- Creates a span with an error highlight.
M.error = hl('DistantError')

--- Creates a span with a warning highlight.
M.warning = hl('DistantWarning')

--- Creates a span with a heading highlight.
M.heading = hl('DistantHeading')

setmetatable(M, {
    __index = function(self, key)
        self[key] = hl(key)
        return self[key]
    end,
})

return M
