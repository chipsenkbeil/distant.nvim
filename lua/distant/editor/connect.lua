local log = require('distant.log')
local state = require('distant.state')

--- @class EditorConnectOpts
--- @field destination string
---
--- @field auth AuthHandler|nil
--- @field options string|table<string, any>
--- @field timeout number|nil
--- @field interval number|nil

--- Connects to a running distance binary on the remote machine
--- @param opts EditorConnectOpts
--- @param cb fun(err:string|nil, client:Client|nil)
return function(opts, cb)
    opts = opts or {}
    cb = cb or function(err)
        if err then
            log.error(err)
        end
    end
    vim.validate({ opts = { opts, 'table' }, cb = { cb, 'function' } })
    log.fmt_trace('editor.connect(%s)', opts)

    -- Load settings for the particular host
    state:load_settings(opts.destination)
    opts = vim.tbl_deep_extend('keep', opts, state.settings or {})

    -- Connect and update our active client
    return state:connect({
        destination = opts.destination,

        -- User-defined settings
        auth = opts.auth,
        timeout = opts.timeout,
        interval = opts.interval,
        options = opts.options,
    }, cb)
end
