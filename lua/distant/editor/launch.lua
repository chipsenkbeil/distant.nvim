local log   = require('distant-core').log
local state = require('distant.state')

--- @class distant.editor.LaunchOpts
--- @field destination string|distant.core.Destination
---
--- @field auth? distant.core.auth.Handler
--- @field distant? distant.editor.launch.DistantOpts
--- @field interval? number
--- @field log_level? 'off'|'error'|'warn'|'info'|'debug'|'trace'
--- @field log_file? string
--- @field options? string|table<string, any>
--- @field timeout? number

--- @class distant.editor.launch.DistantOpts
--- @field bin? string
--- @field args? string

--- Launches a new instance of the distance binary on the remote machine and sets
--- up a session so clients are able to communicate with it
---
--- @param opts distant.editor.LaunchOpts
--- @param cb fun(err?:string, client?:distant.core.Client)
return function(opts, cb)
    opts = opts or {}
    cb = cb or function(err)
        if err then
            log.error(err)
        end
    end
    vim.validate({ opts = { opts, 'table' }, cb = { cb, 'function' } })
    log.fmt_trace('editor.launch(%s)', opts)

    -- Load settings for the particular host
    local destination = opts.destination
    if type(destination) == 'table' then
        --- @type string
        destination = destination:as_string()
    end

    --- @cast destination string
    state:load_settings(destination)
    opts = vim.tbl_deep_extend('keep', opts, state.settings or {})

    -- Create a new client to be used as our active client
    return state:launch({
        destination = destination,
        -- User-defined settings
        auth = opts.auth,
        distant = opts.distant and opts.distant.bin,
        distant_args = opts.distant and opts.distant.args,
        log_file = opts.log_file,
        log_level = opts.log_level,
        options = opts.options,
        timeout = opts.timeout,
        interval = opts.interval,
    }, cb)
end
