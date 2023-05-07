local log   = require('distant-core').log
local state = require('distant.state')

--- @class distant.editor.LaunchOpts
--- @field destination string
---
--- @field auth? distant.auth.Handler
--- @field distant? distant.editor.launch.DistantOpts
--- @field interval? number
--- @field log_level? 'off'|'error'|'warn'|'info'|'debug'|'trace'
--- @field log_file? string
--- @field options? string|table<string, any>
--- @field timeout? number

--- @class distant.editor.launch.DistantOpts
--- @field bin? string
--- @field args? string
--- @field use_login_shell? boolean #true by default unless specified as false

--- Launches a new instance of the distance binary on the remote machine and sets
--- up a session so clients are able to communicate with it
---
--- @param opts distant.editor.LaunchOpts
--- @param cb fun(err?:string, client?:distant.Client)
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
    state:load_settings(destination)
    opts = vim.tbl_deep_extend('keep', opts, state.settings or {})

    -- We want to use a login shell by default unless explicitly told
    -- not to do so
    local use_login_shell = true
    if opts.distant and type(opts.distant.use_login_shell) == 'boolean' then
        use_login_shell = opts.distant.use_login_shell
    end

    -- Create a new client to be used as our active client
    return state:launch({
        destination = opts.destination,
        -- User-defined settings
        auth = opts.auth,
        distant = opts.distant and opts.distant.bin,
        distant_args = opts.distant and opts.distant.args,
        log_file = opts.log_file,
        log_level = opts.log_level,
        no_shell = not use_login_shell,
        options = opts.options,
        timeout = opts.timeout,
        interval = opts.interval,
    }, cb)
end
