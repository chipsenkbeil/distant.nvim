local plugin = require('distant')
local log    = require('distant-core').log

local M      = {}
M.__index    = M

--- Checks a path to see if it exists, returning a table with information.
---
--- Will also canonicalize the `path` provided and return it as part of the result.
---
--- @param opts {path:string, client_id?:distant.core.manager.ConnectionId, timeout?:number, interval?:number}
--- @return {path:string, is_dir:boolean, is_file:boolean, missing:boolean, timestamp:number|nil}
function M.check_path(opts)
    log.fmt_trace('checker.check_path(%s)', opts)

    local path = opts.path

    -- We need to figure out if we are working with a file or directory
    local err, metadata = plugin.api(opts.client_id).metadata({
        path = path,
        canonicalize = true,
        resolve_file_type = true,
        timeout = opts.timeout,
        interval = opts.interval,
    })

    -- Check if the error we got is a missing file. If we get
    -- any other kind of error, we want to throw the error
    --
    -- TODO: With ssh, the error kind is "other" instead of "not_found"
    --       so we may have to do a batch request with exists
    --       to properly validate
    local missing = (err and err.kind == 'not_found') or false
    assert(not err or missing, tostring(err))

    local is_dir = false
    local is_file = false
    local full_path = path
    local timestamp = nil

    if not missing then
        assert(metadata, 'Metadata missing')

        is_dir = metadata.file_type == 'dir'
        is_file = metadata.file_type == 'file'

        -- Use canonicalized path if available
        full_path = metadata.canonicalized_path or path

        -- Use timestamp if available
        timestamp = metadata.modified or metadata.created
    end

    return {
        path = full_path,
        is_dir = is_dir,
        is_file = is_file,
        missing = missing,
        timestamp = timestamp,
    }
end

return M
