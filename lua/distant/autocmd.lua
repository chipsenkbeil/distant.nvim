local editor = require('distant.editor')
local log = require('distant.log')
local s = require('distant.state')
local u = require('distant.utils')

local function _initialize()
    log.trace('Initializing autocmds')

    -- Assign appropriate handlers for distant:// scheme
    u.augroup('distant', function()
        u.autocmd('BufReadCmd', 'distant://*', function()
            local buf = tonumber(vim.fn.expand('<abuf>'))
            local fname = vim.fn.expand('<amatch>')
            local path = u.strip_prefix(fname, 'distant://')

            log.fmt_debug('Reading %s into buf %s', path, buf)
            editor.open(path, {
                buf = buf;
                reload = true;
            })
        end)

        u.autocmd('BufWriteCmd', 'distant://*', function()
            local buf = tonumber(vim.fn.expand('<abuf>'))

            if type(buf) == 'number' and buf ~= -1 then
                log.fmt_debug('Writing buf %s', buf)
                editor.write(buf)
            end
        end)

        -- Define augroup that will stop client when exiting neovim
        u.autocmd('VimLeave', '*', function()
            if s.has_client() then
                s.client():stop()
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
