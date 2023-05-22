local plugin = require('distant')
local log    = require('distant-core').log
local utils  = require('distant-core').utils

--- @class neovim.AutocmdOpts
--- @field id number #autocommand id
--- @field event string  #name of the triggered event
--- @field group? number #autocommand group id, if any
--- @field match string #expanded value of |<amatch>|
--- @field buf number #expanded value of |<abuf>|
--- @field file string #expanded value of |<afile>|
--- @field data any #arbitrary data passed from |nvim_exec_autocmds()|

local function _initialize()
    log.trace('Initializing autocmds')
    local autogroup_id = vim.api.nvim_create_augroup('distant', { clear = true })

    -- If we enter a buffer that is not initialized, we trigger a BufReadCmd
    vim.api.nvim_create_autocmd({ 'BufEnter' }, {
        group = autogroup_id,
        pattern = 'distant://*',
        --- @param opts neovim.AutocmdOpts
        callback = function(opts)
            local bufnr = opts.buf

            if not plugin.buf(bufnr).has_data() then
                log.fmt_debug('Buffer %s is not initialized, so triggering BufReadCmd', bufnr)
                vim.api.nvim_exec_autocmds('BufReadCmd', {
                    group = 'distant',
                    pattern = opts.match,
                })
            end
        end,
    })

    -- Primary entrypoint to load remote files
    vim.api.nvim_create_autocmd({ 'BufReadCmd', 'FileReadCmd' }, {
        group = autogroup_id,
        pattern = 'distant://*',
        --- @param opts neovim.AutocmdOpts
        callback = function(opts)
            local bufnr = opts.buf
            local fname = opts.match

            local components = plugin.buf.parse_name(fname)
            local connection = components.connection
            local path, line, col = utils.strip_line_col(components.path)

            -- Ensure our buffer is named without the line/column,
            -- but with the appropriate prefixes
            vim.api.nvim_buf_set_name(bufnr, plugin.buf.build_name({
                scheme = 'distant',
                connection = connection,
                path = path,
            }))

            log.fmt_debug('Reading %s into buffer %s', path, bufnr)
            plugin.editor.open({
                path = path,
                bufnr = bufnr,
                line = line,
                col = col,
                client_id = connection or plugin.buf(bufnr).client_id(),
                reload = true,
            })
        end,
    })

    -- Primary entrypoint to write remote files
    vim.api.nvim_create_autocmd({ 'BufWriteCmd' }, {
        group = autogroup_id,
        pattern = 'distant://*',
        --- @param opts neovim.AutocmdOpts
        callback = function(opts)
            local bufnr = opts.buf
            if type(bufnr) == 'number' and bufnr ~= -1 then
                log.fmt_debug('Writing buffer %s', bufnr)
                plugin.editor.write({ buf = bufnr })
            end
        end,
    })
end

local is_initialized = false

return {
    --- Configures the autocmds associated with this plugin.
    ---
    --- Subsequent calls will do nothing.
    initialize = function()
        if not is_initialized then
            _initialize()
            is_initialized = true
        end
    end
}
