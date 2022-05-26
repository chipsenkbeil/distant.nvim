local log = require('distant.log')
local state = require('distant.state')

--- @class EditorLaunchOpts
--- @field host string
--- @field mode? 'distant'|'ssh'
--- @field ssh? EditorLaunchSshOpts
--- @field distant? EditorLaunchDistantOpts
--- @field timeout? number
--- @field interval? number

--- @class EditorLaunchSshOpts
--- @field user? string
--- @field port? number

--- @class EditorLaunchDistantOpts
--- @field bin? string
--- @field args? string
--- @field use_login_shell? boolean #true by default unless specified as false

--- Launches a new instance of the distance binary on the remote machine and sets
--- up a session so clients are able to communicate with it
---
--- @param opts EditorLaunchOpts
--- @param cb fun(err:string|boolean, client:Client|nil)
return function(opts, cb)
    opts = opts or {}
    cb = cb or function(err)
        if err then
            log.error(err)
        end
    end
    vim.validate({ opts = { opts, 'table' }, cb = { cb, 'function' } })
    log.fmt_trace('editor.launch(%s)', opts)

    -- Verify that we were provided a host
    local host_type = type(opts.host)
    if host_type ~= 'string' then
        error('opts.host should be string, but got ' .. host_type)
    end

    -- Load settings for the particular host
    state.load_settings(opts.host)
    opts = vim.tbl_deep_extend('keep', opts, state.settings or {})

    -- We want to use a login shell by default unless explicitly told
    -- not to do so
    local use_login_shell = true
    if opts.distant and type(opts.distant.use_login_shell) == 'boolean' then
        use_login_shell = opts.distant.use_login_shell
    end

    state.load_client(opts, function(err, client)
        if err then
            vim.api.nvim_err_writeln(err)
            cb(err)
            return
        end

        -- ssh mode means that launching is actually just connecting underneath
        if opts.mode == 'ssh' then
            client:connect({}, function(err2)
                if err then
                    vim.api.nvim_err_writeln(err2)
                    cb(err2)
                    return
                end

                cb(false, client)
            end)

            -- otherwise, we are actually launching a server on a remote machine
        else
            -- TODO: Use mode to distinguish distant and ssh
            -- TODO: Support overriding on_authenticate and on_host_verify
            client:launch({
                connect = true,

                host = opts.host,
                port = opts.ssh and opts.ssh.port,

                no_shell          = not use_login_shell,
                distant           = opts.distant and opts.distant.bin,
                extra_server_args = opts.distant and opts.distant.args,
                username          = opts.ssh and opts.ssh.user,

                -- TODO: Support these extra settings
                external_ssh   = nil,
                identity_file  = nil,
                log_file       = nil,
                log_level      = nil,
                shutdown_after = nil,
                ssh            = nil,
            }, function(err2)
                if err then
                    vim.api.nvim_err_writeln(err2)
                    cb(err2)
                    return
                end

                cb(false, client)
            end)
        end
    end)
end
