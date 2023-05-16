local log = require('distant-core').log

local M   = {}
M.__index = M

--- Applies neovim buffer-local mappings.
---
--- @param bufnr number
--- @param mappings table<distant.plugin.settings.Keymap, fun()>
function M.apply_mappings(bufnr, mappings)
    log.fmt_trace('mapper.apply_mappings(%s, %s)', bufnr, mappings)

    for lhs, callback in pairs(mappings) do
        -- If we got a single key combination, make it a list of one
        if type(lhs) == 'string' then
            lhs = { lhs }
        end

        -- For each key combination, map our callback to it
        for _, lhs in ipairs(lhs) do
            vim.api.nvim_buf_set_keymap(bufnr, 'n', lhs, '', {
                noremap = true,
                silent = true,
                nowait = true,
                callback = callback,
            })
        end
    end
end

return M
