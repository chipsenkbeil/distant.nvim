local log = require('distant-core').log

local M = {}
M.__index = M

--- Schedules a repair of quickfix markers.
---
--- In the situation where a buf already existed but was not initialized,
--- this is from a list like a quickfix list that had created a buf for
--- a non-file (distant://...) with markers in place before content.
---
--- NOTE: Calling nvim_buf_set_lines invokes `qf_mark_adjust` through `mark_adjust`,
---       which causes the lnum of quickfix, location-list, and marks to get moved
---       incorrectly when we are first populating (going from 1 line to N lines);
---       so, we want to spawn a task that will correct line numbers when shifted
---
--- @param bufnr number #buffer whose markers to repair
function M.schedule_repair_markers(bufnr)
    log.fmt_trace('qflist.schedule_repair_markers(%s)', bufnr)

    local list = vim.fn.getqflist({ id = 0, context = 0 })
    local qfid = list.id

    if list.context and list.context.distant then
        vim.schedule(function()
            list = vim.fn.getqflist({ id = qfid, idx = 0, items = 0 })

            -- If we get lnum > end_lnum, this is from the marker from
            -- the quickfix list getting pushed down from new lines
            for _, item in ipairs(list.items) do
                if item.bufnr == bufnr and item.lnum > item.end_lnum then
                    item.lnum = item.end_lnum
                end
            end

            -- Update list and restore the selected position
            vim.fn.setqflist({}, 'r', { id = list.id, items = list.items })
            vim.fn.setqflist({}, 'a', { id = list.id, idx = list.idx })
        end)
    end
end

--- In the situation where we were loaded by a quickfix list, this moves
--- the cursor to the appropriate location based on the selection.
---
--- Position is only set if distant quickfix with matching buffer for selection
---
--- @param bufnr number
--- @return {line: number, col: number}|nil
function M.get_qflist_selection_cursor(bufnr)
    log.fmt_trace('qflist.get_qflist_selection_cursor(%s)', bufnr)

    local list = vim.fn.getqflist({ id = 0, context = 0 })
    local qfid = list.id

    if list.context and list.context.distant then
        list = vim.fn.getqflist({ id = qfid, idx = 0, items = 0 })

        -- Get line and column from entry only if it is for this buffer
        if list.idx > 0 then
            local item = list.items[list.idx]

            if item and item.bufnr == bufnr then
                local line = item.lnum or 1
                local col = item.col or 0
                local end_line = item.end_lnum or line
                local end_col = item.end_col or col

                if line > end_line then
                    line = end_line
                end

                if col > end_col then
                    col = end_col
                end

                return { line = line, col = col }
            end
        end
    end
end

return M
