local plugin  = require('distant')
local log     = require('distant-core').log
local utils   = require('distant-core').utils

--- @class neovim.AutocmdOpts
--- @field id number #autocommand id
--- @field event string  #name of the triggered event
--- @field group? number #autocommand group id, if any
--- @field match string #expanded value of |<amatch>|
--- @field buf number #expanded value of |<abuf>|
--- @field file string #expanded value of |<afile>|
--- @field data any #arbitrary data passed from |nvim_exec_autocmds()|

--- Patterns supported by distant autocommands.
local PATTERN = { 'distant://*', 'distant+*://*' }

--- Id of the group created.
--- @type number|nil
local autogroup_id

local function _initialize()
    log.debug('Initializing autocmds')
    autogroup_id = vim.api.nvim_create_augroup('distant', { clear = true })

    -- If we enter a buffer that is not initialized, we trigger a BufReadCmd
    vim.api.nvim_create_autocmd({ 'BufEnter' }, {
        group = autogroup_id,
        pattern = PATTERN,
        --- @param opts neovim.AutocmdOpts
        callback = function(opts)
            log.fmt_debug('BufEnter %s', opts)
            local bufnr = opts.buf
            local match = opts.match

            if not plugin.buf(bufnr).has_data() then
                log.fmt_debug('Buffer %s is not initialized, so triggering BufReadCmd', bufnr)
                vim.api.nvim_exec_autocmds('BufReadCmd', {
                    group = 'distant',
                    pattern = match,
                })
            end
        end,
    })

    -- Primary entrypoint to load remote files
    vim.api.nvim_create_autocmd({ 'BufReadCmd', 'FileReadCmd' }, {
        group = autogroup_id,
        pattern = PATTERN,
        --- @param opts neovim.AutocmdOpts
        callback = function(opts)
            log.fmt_debug('BufReadCmd/FileReadCmd %s', opts)
            local bufnr = opts.buf
            local fname = opts.match

            local components = plugin.buf.name.parse({ name = fname })
            local connection = components.connection
            local path, line, col = utils.strip_line_col(components.path)

            -- Ensure our buffer is named without the line/column,
            -- but with the appropriate prefixes
            vim.api.nvim_buf_set_name(bufnr, plugin.buf.name.build({
                scheme = 'distant',
                connection = connection,
                path = path,
            }))

            -- Accept arbitrary data to indicate reload status

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
        pattern = PATTERN,
        --- @param opts neovim.AutocmdOpts
        callback = function(opts)
            log.fmt_debug('BufWriteCmd %s', opts)
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
    end,
    --- @return string[]
    pattern = function()
        return vim.deepcopy(PATTERN)
    end,
    --- @return number|nil
    group = function()
        return autogroup_id
    end
}
