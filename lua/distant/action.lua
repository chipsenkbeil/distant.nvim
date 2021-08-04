local fn = require('distant.fn')
local g = require('distant.internal.globals')
local session = require('distant.session')
local ui = require('distant.internal.ui')
local u = require('distant.internal.utils')
local v = require('distant.internal.vars')

local action = {}

--- Launches a new instance of the distance binary on the remote machine and sets
--- up a session so clients are able to communicate with it
---
--- @param host string host to connect to (e.g. example.com)
--- @param args table of arguments to append to the launch command, where all
---             keys with _ are replaced with - (e.g. my_key -> --my-key)
--- @return number Exit code once launch has completed, or nil if times out
action.launch = function(host, args)
    assert(type(host) == 'string', 'Missing or invalid host argument')
    args = args or {}

    local buf_h = vim.api.nvim_create_buf(false, true)
    assert(buf_h ~= 0, 'Failed to create buffer for launch')

    local info = vim.api.nvim_list_uis()[1]
    local width = 80
    local height = 8
    local win = vim.api.nvim_open_win(buf_h, 1, {
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

    -- Clear any pre-existing session
    g.set_session(nil)

    -- Format is launch {host} [args..]
    -- NOTE: Because this runs in a pty, all output goes to stdout by default;
    --       so, in order to distinguish errors, we write to a temporary file
    --       when launching so we can read the errors and display a msg
    --       if the launch fails
    local err_log = vim.fn.tempname()
    local raw_data = nil
    local cmd_args = u.build_arg_str(u.merge(
        g.settings.launch,
        args,
        {log_file = err_log; session = 'pipe'}
    ))
    local code = vim.fn.termopen(
        g.settings.binary_name .. ' launch ' .. host .. ' ' .. cmd_args,
        {
            stdout_buffered = true;
            on_stdout = function(_, data, _)
                raw_data = data
                for _, line in pairs(data) do
                    line = vim.trim(line)
                    if u.starts_with(line, 'DISTANT DATA') then
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
                            g.set_session(session)
                        end
                    end
                end
            end;
            on_exit = function(_, code, _)
                vim.api.nvim_win_close(win, false)
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
                            if u.starts_with(line, 'ERROR') then
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
                        local lines = u.filter_map(raw_data, function(line)
                            return u.clean_term_line(line)
                        end)
                        ui.show_msg(lines, 'err')
                    end
                end

                if g.session() == nil then
                    ui.show_msg('Failed to acquire session!', 'err')
                end
            end;
        }
    )

    -- If our program failed, report why
    if code == 0 then
        ui.show_msg('Invalid arguments for launch!', 'err')
    elseif code == -1 then
        ui.show_msg(g.settings.binary_name .. ' is not executable!', 'err')
    end
end

--- Opens the provided path in one of two ways:
--- 1. If path points to a file, creates a new `distant` buffer with the contents
--- 2. If path points to a directory, displays a dialog with the immediate directory contents
---
--- @param path string Path to directory to show
--- @param all boolean If true, will recursively search directories
--- @param timeout number Maximum time to wait for a response (optional)
--- @param interval number Time in milliseconds to wait between checks for a response (optional)
action.open = function(path, opts)
    assert(type(path) == 'string', 'path must be a string')
    opts = opts or {}

    -- First, we need to figure out if we are working with a file or directory
    local metadata = fn.metadata(path, timeout, interval)
    if metadata == nil then
        return
    end

    local lines = nil

    -- Second, if the path points to a directory, load the entries as lines
    if metadata.file_type == 'dir' then
        local entries = fn.dir_list(path, not (not opts.all), timeout, interval)
        lines = u.filter_map(entries, function(entry)
            return entry.path
        end)

    -- Third, if path points to a file, load its contents as lines
    elseif metadata.file_type == 'file' then
        local text = fn.read_file_text(path, timeout, interval)
        lines = vim.split(text, '\n', true)
    else
        vim.api.nvim_err_writeln('Filetype ' .. metadata.file_type .. ' is unsupported')
        return
    end

    -- Create a buffer to house the text
    local buf = vim.api.nvim_create_buf(true, false)
    assert(buf ~= 0, 'Failed to create buffer for for remote editing')

    -- Set the content of the buffer to the remote file
    vim.api.nvim_buf_set_lines(buf, 0, 1, false, lines)

    -- Set the buffer name to include a schema, which will trigger our
    -- autocmd for writing to the remote destination
    --
    -- Mark the buftype as acwrite as you can still write to it, but we
    -- control where it is going
    --
    -- Mark as not yet modified as the content we placed into our
    -- buffer matches that of the remote file
    vim.api.nvim_buf_set_name(buf, 'distant://' .. path)
    vim.api.nvim_buf_set_option(buf, 'buftype', 'acwrite')
    vim.api.nvim_buf_set_option(buf, 'modified', false)

    -- Add stateful information to the buffer, helping keep track of it
    v.buf.set_remote_path(buf, path)

    -- Display the buffer in the specified window, defaulting to current
    vim.api.nvim_win_set_buf(opts.win or 0, buf)

    -- Set our filetype to whatever the contents actually are (or file extension is)
    -- TODO: This makes me feel uncomfortable as I do not yet understand why detecting
    --       the filetype as the real type does not trigger neovim's LSP. At the
    --       moment, it does not happen but we still get syntax highlighting, which
    --       is perfect. In the future, we may need to switch this to something similar
    --       to what telescope.nvim does with plenary.nvim's syntax functions.
    --
    -- TODO: Does this work if the above window is not the current one? Would prefer
    --       an explicit function as opposed to the command we're using as don't
    --       have control
    vim.cmd([[ filetype detect ]])
end

--- Opens a new window to show metadata for some path
---
--- @param path string Path to file/directory/symlink to show
--- @param timeout number Maximum time to wait for a response (optional)
--- @param interval number Time in milliseconds to wait between checks for a response (optional)
action.metadata = function(path, timeout, interval)
    assert(type(path) == 'string', 'path must be a string')

    local metadata = fn.metadata(path, timeout, interval)
    local lines = {}
    table.insert(lines, 'Path: "' .. path .. '"')
    table.insert(lines, 'File Type: ' .. metadata.file_type)
    table.insert(lines, 'Len: ' .. tostring(metadata.len) .. ' bytes')
    table.insert(lines, 'Readonly: ' .. tostring(metadata.readonly))
    if metadata.created ~= nil then
        table.insert(lines, 'Created: ' .. vim.fn.strftime(
            '%c', 
            math.floor(metadata.created / 1000.0)
        ))
    end
    if metadata.accessed ~= nil then
        table.insert(lines, 'Last Accessed: ' .. vim.fn.strftime(
            '%c', 
            math.floor(metadata.accessed / 1000.0)
        ))
    end
    if metadata.modified ~= nil then
        table.insert(lines, 'Last Modified: ' .. vim.fn.strftime(
            '%c', 
            math.floor(metadata.modified / 1000.0)
        ))
    end

    ui.show_msg(lines)
end

--- Opens a new window to display session info
action.info = function()
    local indent = '    '
    local info = session.info()
    local distant_buf_names = u.filter_map(vim.api.nvim_list_bufs(), function(buf)
        local name = vim.api.nvim_buf_get_name(buf)
        if u.starts_with(name, 'distant://') then
            return indent .. '* ' .. string.sub(name, string.len('distant://') + 1)
        end
    end)

    local session_info = {'Disconnected'}
    if info ~= nil then
        session_info = {
            indent .. '* Host = "' .. info.host .. '"';
            indent .. '* Port = "' .. info.port .. '"';
            indent .. '* Auth = "' .. info.auth_key .. '"';
        }
    end

    local msg = {}
    vim.list_extend(msg, {
        '= Session =';
        '';
    })
    vim.list_extend(msg, session_info)
    vim.list_extend(msg, {
        '';
        '= Remote Files =';
        '';
    })
    vim.list_extend(msg, distant_buf_names)

    ui.show_msg(msg)
end

return action
