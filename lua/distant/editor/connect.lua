local lib = require('distant.lib')
local log = require('distant.log')
local state = require('distant.state')

--- Connects to a running distance binary on the remote machine
return function(opts, cb)
    opts = opts or {}
    cb = cb or function() end
    vim.validate({opts = {opts, 'table'}, cb = {cb, 'function'}})
    log.fmt_trace('editor.connect(%s)', opts)

    -- Verify that we were provided a host
    local host_type = type(opts.host)
    if host_type ~= 'string' then
        error('opts.host should be string, but got ' .. host_type)
    end

    -- Verify that we were provided a port
    local port_type = type(opts.port)
    if port_type ~= 'number' then
        error('opts.port should be number, but got ' .. port_type)
    end

    local key = vim.fn.inputsecret('Enter distant key: ')
    if #key == 0 then
        error('key cannot be empty')
    end
    opts.key = key

    -- Load settings for the particular host
    state.load_settings(opts.host)
    opts = vim.tbl_deep_extend('keep', opts, state.settings or {})

    -- Clear any pre-existing session
    state.session = nil

    local first_time = not lib.is_loaded()
    lib.load(function(success, res)
        if not success then
            local msg = tostring(res)
            vim.api.nvim_err_writeln(msg)
            cb(false, msg)
            return
        end

        -- Initialize logging of rust module
        if first_time then
            log.init_lib(res)
        end

        local session
        success, session = pcall(res.session.connect, opts)
        if not success then
            local msg = tostring(session)
            vim.api.nvim_err_writeln(msg)
            cb(false, msg)
            return
        end

        state.session = session
        state.sessions[opts.host] = session
        cb(true)
    end)
end
