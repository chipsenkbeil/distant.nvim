local log = require('distant.log')
local state = require('distant.state')

--- @class EditorConnectOpts
--- @field host string
--- @field port number
--- @field key? string
--- @field timeout? number
--- @field interval? number

--- Connects to a running distance binary on the remote machine
--- @param opts EditorConnectOpts
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

    local key = opts.key or vim.fn.inputsecret('Enter distant key: ')
    if #key == 0 then
        error('key cannot be empty')
    end
    opts.key = key

    -- Load settings for the particular host
    state.load_settings(opts.host)
    opts = vim.tbl_deep_extend('keep', opts, state.settings or {})

    state.load_client(opts, function(err, client)
        if err then
            vim.api.nvim_err_writeln(err)
            cb(err)
            return
        end

        client:connect({
            session = {
                host = opts.host,
                port = opts.port,
                key = opts.key,
            }
        })
        cb(false, client)
    end)
end
