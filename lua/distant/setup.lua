local editor = require('distant.editor')
local settings = require('distant.internal.settings')
local u = require('distant.internal.utils')

return function(opts)
    opts = opts or {}

    -- Update our global settings
    settings.merge(opts)

    -- Assign appropriate handlers for distant:// scheme
    u.augroup('distant', function()
        u.autocmd('BufReadCmd', 'distant://*', function()
            local buf = tonumber(vim.fn.expand('<abuf>'))
            local fname = vim.fn.expand('<amatch>')
            local path = u.strip_prefix(fname, 'distant://')
            editor.open(path, {
                buf = buf;
                reload = true;
            })
        end)

        u.autocmd('BufWriteCmd', 'distant://*', function()
            local buf = tonumber(vim.fn.expand('<abuf>'))
            if type(buf) == 'number' and buf ~= -1 then
                editor.write(buf)
            end
        end)
    end)
end
