local editor = require('distant.editor')
local log = require('distant.log')
local u = require('distant.utils')
local vars = require('distant.vars')

local function _initialize()
    log.trace('Initializing autocmds')

    -- Assign appropriate handlers for distant:// scheme
    u.augroup('distant', function()
        -- If we enter a buffer that is not initialized, we trigger a BufReadCmd
        u.autocmd('BufEnter', 'distant://*', function()
            --- @diagnostic disable-next-line:missing-parameter
            local buf = tonumber(vim.fn.expand('<abuf>'))

            if buf > 0 and vars.buf(buf).remote_path.is_unset() then
                log.fmt_debug('buf %s is not initialized, so triggering BufReadCmd', buf)
                vim.api.nvim_exec_autocmds('BufReadCmd', {
                    group = 'distant',
                    --- @diagnostic disable-next-line:missing-parameter
                    pattern = vim.fn.expand('<amatch>'),
                })
            end
        end)

        -- Primary entrypoint to load remote files
        u.autocmd('BufReadCmd,FileReadCmd', 'distant://*', function()
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

        -- Primary entrypoint to write remote files
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
