local g = require('distant.internal.globals')
local fn = require('distant.fn')
local u = require('distant.internal.utils')
local v = require('distant.internal.vars')

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

            -- Load the remote path from the buffer being saved
            local path = v.buf.remote_path(buf)

            -- Load the contents of the buffer
            -- TODO: This only works if the buffer is not hidden, but is
            --       this a problem for the write cmd since the buffer
            --       shouldn't be hidden?
            local lines = vim.fn.getbufline(buf, 1, '$')
            
            -- Write the buffer contents
            fn.write_file_text(path, table.concat(lines, '\n'))

            -- Update buffer as no longer modified
            vim.api.nvim_buf_set_option(buf, 'modified', false)
        end)
    end)
end
