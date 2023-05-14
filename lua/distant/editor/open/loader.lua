local log    = require('distant-core').log
local qflist = require('distant.editor.open.qflist')
local plugin = require('distant')

local M      = {}
M.__index    = M

--- Creates or populates an existing buffer with `lines`.
--- @param opts {bufnr?:number, lines:string[]}
--- @return {bufnr:number, created:boolean}
local function create_or_populate_buf(opts)
    log.fmt_trace('loader.create_or_populate_buf(%s)', opts)
    local bufnr = opts.bufnr
    local buf_created = false

    -- Create a buffer to house the text if no buffer exists
    if bufnr == nil then
        bufnr = vim.api.nvim_create_buf(true, false)
        buf_created = true
        assert(bufnr ~= 0, 'Failed to create buffer for remote editing')
    end

    -- Place lines into buffer, marking the file as modifiable
    -- temporarily so we can load lines, and then changing it back
    -- to whatever state it was before
    --
    -- Since we modified the buffer by adding in the content,
    -- we need to reset it here
    local is_modifiable = vim.api.nvim_buf_get_option(bufnr, 'modifiable')
    vim.api.nvim_buf_set_option(bufnr, 'modifiable', true)
    local line_cnt = vim.api.nvim_buf_line_count(bufnr)
    if line_cnt == 0 then
        line_cnt = 1
    end

    -- In the situation where a buf already existed but was not initialized,
    -- this is from a list like a quickfix list that had created a buf for
    -- a non-file (distant://...) with markers in place before content
    --
    -- NOTE: Calling nvim_buf_set_lines invokes `qf_mark_adjust` through `mark_adjust`,
    --       which causes the lnum of quickfix, location-list, and marks to get moved
    --       incorrectly when we are first populating (going from 1 line to N lines);
    --       so, we want to spawn a task that will correct line numbers when shifted
    if not buf_created and not plugin.buf(bufnr).has_data() then
        qflist.schedule_repair_markers(bufnr)
    end

    vim.api.nvim_buf_set_lines(bufnr, 0, line_cnt, false, opts.lines)

    vim.api.nvim_buf_set_option(bufnr, 'modifiable', is_modifiable)
    vim.api.nvim_buf_set_option(bufnr, 'modified', false)

    return { bufnr = bufnr, created = buf_created }
end

--- @param opts distant.editor.open.LoadOpts
--- @return {bufnr:number, created:boolean}
local function load_buf_from_file(opts)
    log.fmt_trace('loader.load_buf_from_file(%s)', opts)
    local path = opts.path

    local err, text = plugin.api(opts.client_id).read_file_text({
        path = path,
        timeout = opts.timeout,
        interval = opts.interval,
    })
    assert(not err, tostring(err))
    assert(text)

    local lines = vim.split(text, '\n', { plain = true })
    return create_or_populate_buf({
        bufnr = opts.bufnr,
        lines = lines,
    })
end

--- @param opts distant.editor.open.LoadOpts
--- @return {bufnr:number, created:boolean}
local function load_buf_from_dir(opts)
    log.fmt_trace('loader.load_buf_from_dir(%s)', opts)
    local path = opts.path

    local err, payload = plugin.api(opts.client_id).read_dir({
        path = path,
        timeout = opts.timeout,
        interval = opts.interval,
    })
    assert(not err, tostring(err))
    assert(payload)

    local lines = {}
    for _, entry in ipairs(payload.entries) do
        if entry.depth > 0 then
            table.insert(lines, entry.path)
        end
    end

    -- Report an errors we get trying to read entries
    for _, error in ipairs(payload.errors) do
        vim.api.nvim_err_writeln(tostring(error))
    end

    return create_or_populate_buf({
        bufnr = opts.bufnr,
        lines = lines,
    })
end

--- Loads content into a buffer, or creates a new buffer to house the content.
---
--- Returns the number of the buffer where content is placed. On failing to load
---
--- @alias distant.editor.open.LoadOpts {path:string, is_dir:boolean, is_file:boolean, missing:boolean, bufnr?:number, client_id?:string, timeout?:number, interval?:number}
--- @param opts distant.editor.open.LoadOpts
--- @return {bufnr:number, created:boolean}
function M.load(opts)
    opts = opts or {}
    log.fmt_trace('loader.load(%s)', opts)
    assert(type(opts.path) == 'string', 'opts.path missing')
    assert(type(opts.is_dir) == 'boolean', 'opts.is_dir missing')
    assert(type(opts.is_file) == 'boolean', 'opts.is_file missing')
    assert(type(opts.missing) == 'boolean', 'opts.missing missing')

    if opts.is_dir and not opts.missing then
        -- If the path points to a directory, load the entries as lines
        return load_buf_from_dir(opts)
    elseif opts.is_file and not opts.missing then
        -- If path points to a file, load its contents as lines
        return load_buf_from_file(opts)
    else
        -- Otherwise, we set ourselves up to create a new, empty file
        return create_or_populate_buf({
            bufnr = opts.bufnr,
            lines = {},
        })
    end
end

return M
