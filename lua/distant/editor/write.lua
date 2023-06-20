local plugin = require('distant')
local log    = require('distant-core').log

--- @param opts {buf:integer, client_id:integer|nil, path:string, lines:string[]}
local function do_write(opts)
    local buf = opts.buf
    local client_id = opts.client_id
    local path = opts.path
    local lines = opts.lines

    -- Write the buffer contents
    local err, results = plugin.api(client_id).batch({
        sequence = true,
        {
            type = 'file_write_text',
            path = path,
            text = table.concat(lines, '\n')
        },
        {
            type = 'metadata',
            path = path,
        },
    })

    -- Check the response of writing the file
    assert(not err, tostring(err))
    assert(results)

    -- Verify we did not get any errors, otherwise throw them
    for _, response in ipairs(results) do
        if response.type == 'error' then
            error(response.description)
        end
    end

    --- @type distant.core.api.MetadataPayload
    --- @diagnostic disable-next-line:assign-type-mismatch
    local metadata = assert(results[2])
    local mtime = metadata and (metadata.modified or metadata.created)
    if mtime then
        plugin.buf(buf).set_mtime(mtime)
    end

    -- Update buffer as no longer modified
    vim.api.nvim_buf_set_option(buf, 'modified', false)
end

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

    -- Lock our watched status if watching the file
    local watched = plugin.buf(buf).watched()
    if watched == true then
        plugin.buf(buf).set_watched('locked')
    end

    -- Perform the write, capturing the error
    -- so we can reset our watch status before
    -- throwing the error
    local ok, err = pcall(do_write, {
        buf = buf,
        client_id = client_id,
        lines = lines,
        path = path,
    })

    -- Reset our locked status
    plugin.buf(buf).set_watched(watched)

    -- Throw our error if we got one earlier
    assert(ok, err)

    return true
end
