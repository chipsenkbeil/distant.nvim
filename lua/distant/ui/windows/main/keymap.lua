local keymap = require('distant.ui.keymap')
local plugin = require('distant')

local M = {}

--- Given a highlight function, will return a series of spans representing the help key.
--- @param hl fun(text:string):distant.core.ui.Span
--- @param sep? distant.core.ui.Span # optional separator to use between spans
--- @return distant.core.ui.Span[]
function M.help_key_spans(hl, sep)
    return keymap.keymap_tospans(plugin.settings.keymap.ui.main.tabs.goto_help, function(lhs)
        return hl(lhs)
    end, sep)
end

return M
