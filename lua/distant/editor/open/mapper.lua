local data = require('distant-core').data
local log  = require('distant-core').log

local M    = {}
M.__index  = M

--- Applies neovim buffer-local mappings
---
--- @param bufnr number
--- @param mappings table<string, fun()>
function M.apply_mappings(bufnr, mappings)
    log.fmt_trace('mapper.apply_mappings(%s, %s)', bufnr, mappings)

    -- Take the global mappings specified for navigation and apply them
    -- TODO: Since these mappings are global, should we set them once
    --       elsewhere and look them up by key instead?
    local fn_ids = {}
    for lhs, rhs in pairs(mappings) do
        local id = 'buf_' .. bufnr .. '_key_' .. string.gsub(lhs, '.', string.byte)
        data.set(id, rhs)
        table.insert(fn_ids, id)
        local key_mapping = '<Cmd>' .. data.get_as_key_mapping(id) .. '<CR>'
        vim.api.nvim_buf_set_keymap(bufnr, 'n', lhs, key_mapping, {
            noremap = true,
            silent = true,
            nowait = true,
        })
    end

    -- When the buffer is detached, we want to clear the global functions
    if not vim.tbl_isempty(fn_ids) then
        vim.api.nvim_buf_attach(bufnr, false, {
            on_detach = function()
                for _, id in ipairs(fn_ids) do
                    data.remove(id)
                end
            end,
        })
    end
end

return M
