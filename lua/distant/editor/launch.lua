local lib = require('distant.lib')
local log = require('distant.log')
local state = require('distant.state')

--- Launches a new instance of the distance binary on the remote machine and sets
--- up a session so clients are able to communicate with it
return function(opts)
    opts = opts or {}
    vim.validate({opts = {opts, 'table'}})
    log.fmt_trace('editor.launch(%s)', opts)

    -- Verify that we were provided a host
    local host_type = type(opts.host)
    if host_type ~= 'string' then
        error('opts.host should string, but got ' .. host_type)
    end

    -- Load settings for the particular host
    state.load_settings(opts.host)

    -- Clear any pre-existing session
    state.set_session(nil)

    -- Inject custom handlers for launching
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
    opts.on_banner = function(banner)
        print(banner)
    end
    opts.on_host_verify = function(msg)
        local answer = vim.fn.input(string.format('%s\nEnter [y/N]> ', msg))
        return answer == 'y' or answer == 'Y' or answer == 'yes' or answer == 'YES'
    end
    opts.on_error = function(err)
        vim.api.nvim_err_writeln(err)
    end

    lib.load(function(success, res)
        if not success then
            vim.api.nvim_err_writeln(tostring(res))
            return
        end

        local session
        success, session = res.session.launch(opts)
        if not success then
            vim.api.nvim_err_writeln(tostring(session))
            return
        end

        state.set_session(session)
    end)
end
