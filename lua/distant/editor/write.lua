local plugin = require('distant')
local log    = require('distant-core').log

--- Writes a buffer to disk on the remote machine
--- @param opts number|{buf:number, timeout?:number, interval?:number}
--- @return boolean
return function(opts)
    opts = opts or {}
    if type(opts) == 'number' then
        opts = { buf = opts }
    end

    log.fmt_trace('editor.write(%s)', opts)
    vim.validate({ opts = { opts, 'table' } })

    local buf = opts.buf
    if not buf then
        error('opts.buf is required')
    end

    -- Load the remote path from the buffer being saved
    local path = plugin.buf(buf).path()

    -- Not a remote file, so don't do anything
    if path == nil then
        return false
    end

    -- Load the contents of the buffer
    -- TODO: This only works if the buffer is not hidden, but is
    --       this a problem for the write cmd since the buffer
    --       shouldn't be hidden? Otherwise, an empty list is returned.
    --- @diagnostic disable-next-line:param-type-mismatch
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

    -- Make sure we're using the right client
    local client_id = plugin.buf(buf).client_id()

    -- Write the buffer contents
    local err, _ = plugin.api(client_id).write_file_text(vim.tbl_extend('keep', {
        path = path,
        text = table.concat(lines, '\n')
    }, opts))
    assert(not err, tostring(err))

    -- Update buffer as no longer modified
    vim.api.nvim_buf_set_option(buf, 'modified', false)
    return true
end
