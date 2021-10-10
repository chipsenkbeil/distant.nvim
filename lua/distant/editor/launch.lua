local lib = require('distant.lib')
local log = require('distant.log')
local state = require('distant.state')

--- Launches a new instance of the distance binary on the remote machine and sets
--- up a session so clients are able to communicate with it
return function(opts, cb)
    opts = opts or {}
    cb = cb or function() end
    vim.validate({opts = {opts, 'table'}, cb = {cb, 'function'}})
    log.fmt_trace('editor.launch(%s)', opts)

    -- Verify that we were provided a host
    local host_type = type(opts.host)
    if host_type ~= 'string' then
        error('opts.host should be string, but got ' .. host_type)
    end

    -- Load settings for the particular host
    state.load_settings(opts.host)

    -- Clear any pre-existing session
    state.session = nil

    if not opts.on_authenticate then
        opts.on_authenticate = function(ev)
            if ev.username then
                print('Authentication for ' .. ev.username)
            end
            if ev.instructions then
                print(ev.instructions)
            end

            local answers = {}
            for _, p in ipairs(ev.prompts) do
                if p.echo then
                    table.insert(answers, vim.fn.input(p.prompt))
                else
                    table.insert(answers, vim.fn.inputsecret(p.prompt))
                end
            end
            return answers
        end
    end

    if not opts.on_banner then
        opts.on_banner = function(banner)
            print(banner)
        end
    end

    if not opts.on_host_verify then
        opts.on_host_verify = function(msg)
            local answer = vim.fn.input(string.format('%s\nEnter [y/N]> ', msg))
            return answer == 'y' or answer == 'Y' or answer == 'yes' or answer == 'YES'
        end
    end

    if not opts.on_error then
        opts.on_error = function(err)
            vim.api.nvim_err_writeln(err)
        end
    end

    lib.load(function(success, res)
        if not success then
            local msg = tostring(res)
            vim.api.nvim_err_writeln(msg)
            cb(false, msg)
            return
        end

        -- TODO: Remove this test log
        -- TODO: CHIP CHIP CHIP terminal mode is useless as it interrupts neovim,
        --       so unless we can provide a callback or some way to map logging
        --       to neovim's console, we should disable that in the C module
        res.log.init({
            file = '/tmp/chip.log',
            level = 'trace',
        })

        local session
        success, session = pcall(res.session.launch, opts)
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
