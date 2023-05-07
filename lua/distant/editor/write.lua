local fn   = require('distant.fn')
local log  = require('distant-core').log
local vars = require('distant-core').vars

--- @class distant.editor.WriteOpts
--- @field buf number #The handle of the buffer to write
--- @field timeout? number #Maximum time to wait for a response
--- @field interval? number #Time in milliseconds to wait between checks for a response

--- Writes a buffer to disk on the remote machine
--- @param opts number|distant.editor.WriteOpts
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
    --- @type string|nil
    local path = vars.buf(buf).remote_path.get()

    if path ~= nil then
        -- Load the contents of the buffer
        -- TODO: This only works if the buffer is not hidden, but is
        --       this a problem for the write cmd since the buffer
        --       shouldn't be hidden?
        --- @diagnostic disable-next-line:param-type-mismatch
        local lines = vim.fn.getbufline(buf, 1, '$')

        -- Write the buffer contents
        local err, _ = fn.write_file_text(vim.tbl_extend('keep', {
            path = path,
            text = table.concat(lines, '\n')
        }, opts))
        assert(not err, tostring(err))

        -- Update buffer as no longer modified
        vim.api.nvim_buf_set_option(buf, 'modified', false)
    end
end
