local editor = require('distant.editor')
local g = require('distant.internal.globals')
local u = require('distant.internal.utils')

return function(opts)
    opts = opts or {}

    -- Update our global settings
    g.settings = u.merge(g.settings, opts)

    -- Assign appropriate handlers for distant filetypes
    u.augroup('distant', function()
        u.autocmd('FileWriteCmd', 'distant://*', function()
            vim.api.nvim_err_writeln('FileWriteCmd unsupported')
        end)

        u.autocmd('FileAppendCmd', 'distant://*', function()
            vim.api.nvim_err_writeln('FileAppendCmd unsupported')
        end)

        u.autocmd('BufWriteCmd', 'distant://*', function()
            local buf = tonumber(vim.fn.expand('<abuf>'))
            editor.write(buf)
        end)

        u.autocmd('BufReadCmd', 'distant://*', function()
            local fname = vim.fn.expand('<afile>')
            local path = u.strip_prefix(fname, 'distant://')
            local buf = editor.open(path, {reload = true})

            -- NOTE: editor.open a new buffer or jumps to an existing buffer that
            --       uses the canonicalized path, so we need to close the any buffer
            --       that is open with the non-canonicalized name
            if fname ~= vim.api.nvim_buf_get_name(buf) then
                buf = vim.fn.bufnr(fname)
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
