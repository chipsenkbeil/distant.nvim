local log               = require('distant-core').log
local plugin            = require('distant')
local validate_callable = require('distant-core').utils.validate_callable

--- @alias distant.editor.connect.Destination
--- | string
--- | distant.core.Destination

--- @class distant.editor.ConnectOpts
--- @field destination distant.editor.connect.Destination
---
--- @field auth? distant.core.AuthHandler
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
    vim.validate({ opts = { opts, 'table' }, cb = { cb, validate_callable() } })
    log.fmt_trace('editor.connect(%s)', opts)

    -- Load settings for the particular host
    local destination = opts.destination
    if type(destination) == 'table' then
        --- @type string
        destination = destination:as_string()
    end

    -- Connect and update our active client
    return plugin:connect({
        destination = destination,
        -- User-defined settings
        auth = opts.auth,
        log_file = opts.log_file,
        log_level = opts.log_level,
        timeout = opts.timeout,
        interval = opts.interval,
        options = opts.options,
    }, cb)
end
