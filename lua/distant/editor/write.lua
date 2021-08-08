local fn = require('distant.fn')
local v = require('distant.internal.vars')

--- Writes a buffer to disk on the remote machine
---
--- @param buf number The handle of the buffer to write
--- @param opts.timeout number Maximum time to wait for a response (optional)
--- @param opts.interval number Time in milliseconds to wait between checks for a response (optional)
return function(buf, opts)
    -- Load the remote path from the buffer being saved
    local path = v.buf.remote_path(buf)

    if path ~= nil then
        -- Load the contents of the buffer
        -- TODO: This only works if the buffer is not hidden, but is
        --       this a problem for the write cmd since the buffer
        --       shouldn't be hidden?
        local lines = vim.fn.getbufline(buf, 1, '$')

        -- Write the buffer contents
        fn.write_file_text(path, table.concat(lines, '\n'), opts)

        -- Update buffer as no longer modified
        vim.api.nvim_buf_set_option(buf, 'modified', false)
    end
end
