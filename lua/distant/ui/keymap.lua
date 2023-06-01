local ui = require('distant-core.ui')

local M = {}

--- Converts a keymap to a node comprised of a span per entry.
--- @param keymap distant.plugin.settings.Keymap
--- @param f fun(lhs:string):distant.core.ui.Span
--- @param sep? distant.core.ui.Span # optional span to use to separate keymap spans
--- @return distant.core.ui.HlTextNode
function M.keymap_tonode(keymap, f, sep)
    return ui.HlTextNode({ M.keymap_tospans(keymap, f, sep) })
end

--- Converts a keymap to a span per entry.
--- @param keymap distant.plugin.settings.Keymap
--- @param f fun(lhs:string):distant.core.ui.Span
--- @param sep? distant.core.ui.Span # optional span to use to separate keymap spans
--- @return distant.core.ui.Span[]
function M.keymap_tospans(keymap, f, sep)
    --- @type distant.core.ui.Span[]
    local spans = {}

    if type(keymap) == 'table' then
        spans = vim.tbl_map(f, keymap)
    else
        table.insert(spans, f(keymap))
    end

    if type(sep) == 'table' then
        local _spans = spans
        spans = {}

        -- Build our list separated by the sep span
        for idx, span in ipairs(_spans) do
            table.insert(spans, span)

            -- If we have more spans remaining, add our separator
            if _spans[idx + 1] ~= nil then
                table.insert(spans, vim.deepcopy(sep))
            end
        end
    end

    return spans
end

return M
