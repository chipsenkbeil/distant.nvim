local editor = require('distant.editor')
local settings = require('distant.internal.settings')
local s = require('distant.internal.state')
local u = require('distant.internal.utils')
local v = require('distant.internal.vars')

return function(opts)
    opts = opts or {}

    -- Update our global settings
    settings.merge(opts)

    -- Assign appropriate handlers for distant filetypes
    u.augroup('distant', function()
        -- Register a command to receive distant:// schema and turn
        -- it into a buffer without the schema
        u.autocmd('BufReadCmd', 'distant://*', function()
            local fname = vim.fn.expand('<afile>')
            local path = u.strip_prefix(fname, 'distant://')
            local buf = editor.open(path, {reload = true})

            -- NOTE: editor.open a new buffer or jumps to an existing buffer that
            --       uses the canonicalized path, so we need to close the any buffer
            --       that is open with the non-canonicalized name
            if path ~= vim.api.nvim_buf_get_name(buf) then
                buf = vim.fn.bufnr('^' .. fname .. '$')
                if buf ~= -1 then
                    vim.api.nvim_buf_delete(buf, {
                        force = true,
                        unload = false,
                    })
                end
            end
        end)
    end)
end
