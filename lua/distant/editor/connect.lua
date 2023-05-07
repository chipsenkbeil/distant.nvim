local log   = require('distant-core').log
local state = require('distant.state')

--- @class distant.editor.ConnectOpts
--- @field destination string
---
--- @field auth? distant.core.auth.Handler
--- @field interval? number
--- @field log_level? 'off'|'error'|'warn'|'info'|'debug'|'trace'
--- @field log_file? string
--- @field options? string|table<string, any>
--- @field timeout? number

--- Connects to a running distance binary on the remote machine
--- @param opts distant.editor.ConnectOpts
--- @param cb fun(err?:string, client?:distant.core.Client)
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
        log_file = opts.log_file,
        log_level = opts.log_level,
        timeout = opts.timeout,
        interval = opts.interval,
        options = opts.options,
    }, cb)
end
