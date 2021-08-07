local fn = require('distant.fn')
local g = require('distant.internal.globals')
local ui = require('distant.internal.ui')
local u = require('distant.internal.utils')
local v = require('distant.internal.vars')

--- Provides editor-oriented operations
local editor = {}

--- Launches a new instance of the distance binary on the remote machine and sets
--- up a session so clients are able to communicate with it
---
--- @param host string host to connect to (e.g. example.com)
--- @param args table of arguments to append to the launch command, where all
---             keys with _ are replaced with - (e.g. my_key -> --my-key)
--- @return number Exit code once launch has completed, or nil if times out
editor.launch = function(host, args)
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
    ), {'verbose'})
    if type(args.verbose) == 'number' and args.verbose > 0 then
        args = vim.trim(args .. ' -' .. string.rep('v', args.verbose))
    end

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
                        lines = u.filter_map(raw_data, function(line)
                            return u.clean_term_line(line)
                        end)
                        ui.show_msg(lines, 'err')
                    end
                end

                if g.session() == nil then
                    ui.show_msg('Failed to acquire session!', 'err')
                else
                    -- Warm up our client if we were successful
                    g.client()
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

--- Opens the provided path in one of three ways:
---
--- 1. If path points to a file, creates a new `distant` buffer with the contents
--- 2. If path points to a directory, opens up a navigation interface
--- 3. If path does not exist, opens a blank buffer that points to the file to be written
---
--- @param path string Path to directory to show
--- @param opts.reload boolean If true, will reload the buffer even if already open
--- @param opts.timeout number Maximum time to wait for a response (optional)
--- @param opts.interval number Time in milliseconds to wait between checks for a response (optional)
editor.open = function(path, opts)
    assert(type(path) == 'string', 'path must be a string')
    opts = opts or {}

    -- We need to figure out if we are working with a file or directory
    local metadata = fn.metadata(path, u.merge(opts, {canonicalize = true}))

    local lines = nil
    local does_not_exist = metadata == nil
    local is_dir = not does_not_exist and metadata.file_type == 'dir'
    local is_file = does_not_exist or metadata.file_type == 'file'

    -- Use canonicalized path if available
    local full_path = path
    if not does_not_exist then
        full_path = metadata.canonicalized_path or path
    end

    -- Figure out the buffer name, which is just its full path with
    -- a schema prepended
    local buf_name = 'distant://' .. full_path
    local buf = vim.fn.bufnr(buf_name)
    local buf_exists = buf ~= -1

    -- If we already have a buffer and we are not reloading, just
    -- switch to it
    if buf_exists and not opts.reload then
        vim.api.nvim_win_set_buf(0, buf)
        return
    end

    -- If the path points to a directory, load the entries as lines
    if is_dir then
        local entries = fn.dir_list(full_path, opts)
        lines = u.filter_map(entries, function(entry)
            if entry.depth > 0 then
                return entry.path
            end
        end)

    -- If path points to a file, load its contents as lines
    elseif is_file and not does_not_exist then
        local text = fn.read_file_text(full_path, opts)
        lines = vim.split(text, '\n', true)

    -- If the path does not exist, we will create a blank buffer
    elseif does_not_exist then
        lines = {}
    else
        vim.api.nvim_err_writeln('Filetype ' .. metadata.file_type .. ' is unsupported')
        return
    end

    -- Create a buffer to house the text if no buffer exists
    if not buf_exists then
        buf = vim.api.nvim_create_buf(true, false)
        assert(buf ~= 0, 'Failed to create buffer for for remote editing')
    end

    -- Set the content of the buffer to the remote file
    vim.api.nvim_buf_set_option(buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(buf, 0, 1, false, lines)
    if is_dir then
        vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    end

    -- Since we modified the buffer by adding in the content for
    -- a file or directory, we need to reset it here
    vim.api.nvim_buf_set_option(buf, 'modified', false)

    -- If our buffer already existed, this is all we want to do as everything
    -- beyond this point is first-time setup
    if buf_exists then
        return
    end

    -- Set the buffer name to include a schema, which will trigger our
    -- autocmd for writing to the remote destination in the situation
    -- where we are editing a file
    vim.api.nvim_buf_set_name(buf, buf_name)

    -- Set file/dir specific options
    if is_file then
        -- Mark the buftype as acwrite as you can still write to it, but we
        -- control where it is going
        vim.api.nvim_buf_set_option(buf, 'buftype', 'acwrite')
    elseif is_dir then
        -- Mark the buftype as nofile and not modifiable as you cannot
        -- modify it or write it; also explicitly set a custom filetype
        vim.api.nvim_buf_set_option(buf, 'filetype', 'distant-nav')
        vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
        vim.api.nvim_buf_set_option(buf, 'modifiable', false)

        -- Take the global mappings specified for navigation and apply them
        -- TODO: Since these mappings are global, should we set them once
        --       elsewhere and look them up by key instead?
        local fn_ids = {}
        for lhs, rhs in pairs(g.settings.nav.mappings) do
            local id = g.fn.insert(rhs)
            table.insert(fn_ids, id)
            local key_mapping = '<Cmd>' .. g.fn.get_as_key_mapping(id) .. '<CR>'
            vim.api.nvim_buf_set_keymap(buf, 'n', lhs, key_mapping, {
                noremap = true,
                silent = true,
                nowait = true,
            })
        end

        -- When the buffer is detached, we want to clear the global functions
        if not vim.tbl_isempty(fn_ids) then
            vim.api.nvim_buf_attach(buf, false, {
                on_detach = function()
                    for _, id in ipairs(fn_ids) do
                        g.fn.remove(id)
                    end
                end;
            })
        end
    end

    -- Add stateful information to the buffer, helping keep track of it
    v.buf.set_remote_path(buf, full_path)

    -- Display the buffer in the specified window, defaulting to current
    vim.api.nvim_win_set_buf(opts.win or 0, buf)

    if is_file then
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
end

--- Opens a new window to show metadata for some path
---
--- @param path string Path to file/directory/symlink to show
--- @param opts.canonicalize boolean If true, includes a canonicalized version
---        of the path in the response
--- @param opts.timeout number Maximum time to wait for a response (optional)
--- @param opts.interval number Time in milliseconds to wait between checks for a response (optional)
editor.show_metadata = function(path, opts)
    assert(type(path) == 'string', 'path must be a string')
    opts = opts or {}

    local metadata = fn.metadata(path, opts)
    local lines = {}
    table.insert(lines, 'Path: "' .. path .. '"')
    if metadata.canonicalized_path then
        table.insert(lines, 'Canonicalized Path: "' .. metadata.canonicalized_path .. '"')
    end
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

--- Opens a new window to display system info
--
--- @param opts.timeout number Maximum time to wait for a response (optional)
--- @param opts.interval number Time in milliseconds to wait between checks for a response (optional)
editor.show_system_info = function(opts)
    opts = opts or {}

    local indent = '    '
    local info = fn.system_info(opts)
    if info ~= nil then
        ui.show_msg({
            '= System Info =';
            '';
            indent .. '* Family      = "' .. info.family .. '"';
            indent .. '* OS          = "' .. info.os .. '"';
            indent .. '* Arch        = "' .. info.arch .. '"';
            indent .. '* Current Dir = "' .. info.current_dir .. '"';
            indent .. '* Main Sep    = "' .. info.main_separator .. '"';
        })
    end
end

--- Opens a new window to display session info
editor.show_session_info = function()
    local indent = '    '
    local session = g.session()
    local distant_buf_names = u.filter_map(vim.api.nvim_list_bufs(), function(buf)
        local name = vim.api.nvim_buf_get_name(buf)
        if u.starts_with(name, 'distant://') then
            return indent .. '* ' .. string.sub(name, string.len('distant://') + 1)
        end
    end)

    local session_info = {'Disconnected'}
    if session ~= nil then
        session_info = {
            indent .. '* Host = "' .. session.host .. '"';
            indent .. '* Port = "' .. session.port .. '"';
            indent .. '* Auth = "' .. session.auth_key .. '"';
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

return editor
