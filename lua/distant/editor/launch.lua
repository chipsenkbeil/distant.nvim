local core = require('distant-core')
local log = core.log
local state = core.state

--- @class EditorLaunchOpts
--- @field destination string
---
--- @field auth AuthHandler|nil
--- @field distant EditorLaunchDistantOpts|nil
--- @field interval number|nil
--- @field log_level DistantLogLevel|nil
--- @field log_file string|nil
--- @field options string|table<string, any>
--- @field timeout number|nil

--- @class EditorLaunchDistantOpts
--- @field bin string|nil
--- @field args string|nil
--- @field use_login_shell boolean|nil #true by default unless specified as false

--- Launches a new instance of the distance binary on the remote machine and sets
--- up a session so clients are able to communicate with it
---
--- @param opts EditorLaunchOpts
--- @param cb fun(err:string|nil, client:DistantClient|nil)
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
