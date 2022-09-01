local editor = require('distant.editor')
local log = require('distant.log')
local u = require('distant.utils')

local function _initialize()
    log.trace('Initializing autocmds')

    -- Assign appropriate handlers for distant:// scheme
    u.augroup('distant', function()
        u.autocmd('BufReadCmd', 'distant://*', function()
            --- @diagnostic disable-next-line:missing-parameter
            local buf = tonumber(vim.fn.expand('<abuf>'))

            --- @diagnostic disable-next-line:missing-parameter
            local fname = vim.fn.expand('<amatch>')
            local path = u.strip_prefix(fname, 'distant://')

            local line, col
            path, line, col = u.strip_line_col(path)

            -- Ensure our buffer is named without the line/column
            vim.api.nvim_buf_set_name(buf, path)

            log.fmt_debug('Reading %s into buf %s', path, buf)
            editor.open({
                path = path,
                buf = buf,
                reload = true,
                line = line,
                col = col,
            })
        end)

        u.autocmd('BufWriteCmd', 'distant://*', function()
            --- @diagnostic disable-next-line:missing-parameter
            local buf = tonumber(vim.fn.expand('<abuf>'))

            if type(buf) == 'number' and buf ~= -1 then
                log.fmt_debug('Writing buf %s', buf)
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
