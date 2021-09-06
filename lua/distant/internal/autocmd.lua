local editor = require('distant.editor')
local u = require('distant.internal.utils')

local function _initialize()
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

local is_initialized = false

return {
    --- Configures the autocmds associated with this plugin
    ---
    --- Subsequent calls will do nothing
    initialize = function()
        if not is_initialized then
            _initialize()
            is_initialized = true
        end
    end
}
