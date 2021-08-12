local s = require('distant.internal.state')
local ui = require('distant.internal.ui')
local u = require('distant.internal.utils')

local DEFAULT_WIDTH = 80
local DEFAULT_HEIGHT = 8

--- Launches a new instance of the distance binary on the remote machine and sets
--- up a session so clients are able to communicate with it
---
--- @param host string host to connect to (e.g. example.com)
--- @param args table of arguments to append to the launch command, where all
---             keys with _ are replaced with - (e.g. my_key -> --my-key)
--- @return number Exit code once launch has completed, or nil if times out
return function(host, args)
    assert(type(host) == 'string', 'Missing or invalid host argument')
    args = args or {}

    -- If we are running headless, info will be nil, which is the case for our tests
    local info = vim.api.nvim_list_uis()[1]

    -- Load settings for the particular host
    s.load_settings(host)

    -- Clear any pre-existing session
    s.set_session(nil)

    -- Format is launch {host} [args..]
    -- NOTE: Because this runs in a pty, all output goes to stdout by default;
    --       so, in order to distinguish errors, we write to a temporary file
    --       when launching so we can read the errors and display a msg
    --       if the launch fails
    local err_log = vim.fn.tempname()
    local raw_data = nil
    local cmd_args = u.build_arg_str(u.merge(
        s.settings.launch,
        args,
        {log_file = err_log; session = 'pipe'}
    ), {'verbose'})
    if type(args.verbose) == 'number' and args.verbose > 0 then
        args = vim.trim(args .. ' -' .. string.rep('v', args.verbose))
    end

    -- If we have a visual way to present, do so
    local run = nil
    local win = nil
    if info ~= nil then
        local buf = vim.api.nvim_create_buf(false, true)
        assert(buf ~= 0, 'Failed to create buffer for launch')

        local width = DEFAULT_WIDTH
        local height = DEFAULT_HEIGHT
        win = vim.api.nvim_open_win(buf, 1, {
            relative = 'editor';
            width = width;
            height = height;
            col = (info.width / 2) - (width / 2);
            row = (info.height / 2) - (height / 2);
            anchor = 'NW';
            style = 'minimal';
            border = 'single';
            noautocmd = true;
        })

        run = vim.fn.termopen

    -- Otherwise, we will run the job in the background, designed for headless mode
    else
        run = vim.fn.jobstart
    end

    local code = run(
        s.settings.binary_name .. ' launch ' .. host .. ' ' .. cmd_args,
        {
            stdout_buffered = true;
            on_stdout = function(_, data, _)
                raw_data = data
                for _, line in pairs(data) do
                    line = vim.trim(line)
                    if vim.startswith(line, 'DISTANT DATA') then
                        local tokens = vim.split(line, ' ', true)
                        local session = {
                            host = tokens[3];
                            port = tonumber(tokens[4]);
                            auth_key = tokens[5];
                        }
                        if session.host == nil then
                            u.log_err('Session missing host')
                        end
                        if session.port == nil then
                            u.log_err('Session missing port')
                        end
                        if session.auth_key == nil then
                            u.log_err('Session missing auth key')
                        end
                        if session.host and session.port and session.auth_key then
                            s.set_session(session)
                        end
                    end
                end
            end;
            on_exit = function(_, code, _)
                if win ~= nil then
                    vim.api.nvim_win_close(win, false)
                end

                if code ~= 0 then
                    local lines = u.read_lines_and_remove(err_log)

                    if lines then
                        -- Strip lines of [date/time] ERROR [src/file] prefix
                        local err_lines = u.filter_map(lines, function(line)
                            -- Remove [date/time] and [src/file] parts
                            line = vim.trim(string.gsub(
                                line,
                                '%[[^%]]+%]',
                                ''
                            ))

                            -- Only keep error lines and remove the ERROR prefix
                            if vim.startswith(line, 'ERROR') then
                                return vim.trim(string.sub(line, 6))
                            end
                        end)

                        -- If we have ERROR lines, report just those
                        if #err_lines > 0 then
                            ui.show_msg(err_lines, 'err')

                        -- Otherwise, just report all of our log output
                        else
                            ui.show_msg(lines, 'err')
                        end
                    else
                        lines = u.filter_map(raw_data, function(line)
                            return u.clean_term_line(line)
                        end)
                        ui.show_msg(lines, 'err')
                    end
                end

                if s.session() == nil then
                    ui.show_msg({
                        'Failed to acquire session!',
                        'Errors logged to ' .. err_log,
                    }, 'err')
                else
                    -- Warm up our client if we were successful
                    s.client()
                end
            end;
        }
    )

    -- If our program failed, report why
    if code == 0 then
        ui.show_msg('Invalid arguments for launch!', 'err')
    elseif code == -1 then
        ui.show_msg(s.settings.binary_name .. ' is not executable!', 'err')
    end
end
