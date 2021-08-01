local fn = require('distant.fn')
local g = require('distant.globals')
local session = require('distant.session')
local u = require('distant.utils')

local ui = {}

--- Launches a new instance of the distance binary on the remote machine and sets
--- up a session so clients are able to communicate with it
---
--- @param host string host to connect to (e.g. example.com)
--- @param args table of arguments to append to the launch command, where all
---             keys with _ are replaced with - (e.g. my_key -> --my-key)
--- @return number Exit code once launch has completed, or nil if times out
ui.launch = function(host, args)
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

    -- Format is launch {host} [args..]
    -- NOTE: Because this runs in a pty, all output goes to stdout by default;
    --       so, in order to distinguish errors, we write to a temporary file
    --       when launching so we can read the errors and display a msg
    --       if the launch fails
    local err_log = vim.fn.tempname()
    local cmd_args = u.build_arg_str(u.merge(
        g.settings.launch, 
        args, 
        {log_file = err_log}
    ))
    vim.fn.termopen(
        g.settings.binary_name .. ' launch ' .. host .. ' ' .. cmd_args,
        {
            on_exit = function(_, code, _)
                vim.api.nvim_win_close(win, false)
                if code ~= 0 then
                    local lines = vim.fn.readfile(err_log)
                    vim.fn.delete(err_log)

                    -- Strip lines of [date/time] ERROR [src/file] prefix
                    lines = u.filter_map(lines, function(line)
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

                    ui.show_msg(lines, 'err')
                end
            end
        }
    )
end


--- Opens a new window to display session info
ui.show_session_info = function()
    local info = session.info()
    ui.show_msg({
        'Host: ' .. info.host;
        'Port: ' .. info.port;
    })
end

--- Opens a new window to show list of files, directories, and
--- symlinks within a directory
---
--- @param path string Path to directory to show
--- @param all boolean If true, will recursively search the directory
ui.show_dir_list = function(path, all)
    assert(type(path) == 'string', 'path must be a string')
    all = not (not all)

    local entries = fn.dir_list(path, all)
    local lines = u.filter_map(entries, function(entry)
        return entry.path
    end)

    if lines ~= nil then
        ui.show_msg(lines)
    end
end

--- Displays a popup window with the provided message
---
--- @param msg string|table contains the message to display
--- @param ty string The type of window to show ('msg', 'err')
--- @param width number width of the window (optional)
--- @param height number height of the window (optional)
ui.show_msg = function(msg, ty, width, height, closing_keys)
    local buf_h = vim.api.nvim_create_buf(false, true)
    assert(buf_h ~= 0, 'Failed to create buffer for session info')

    local info = vim.api.nvim_list_uis()[1]

    -- Get lines as a list
    if type(msg) == 'table' then
        msg = table.concat(msg, '\n')
    end
    local lines = u.filter_map(vim.split(msg, '\n', true), function(line)
        line = vim.trim(line)
        if line ~= nil and line ~= '' then
            return line
        end
    end)

    -- Set some defaults
    ty = ty or 'msg'
    width = width or 80
    height = height or #lines

    -- Keep width & height within sane boundaries
    height = math.max(height, 8)
    height = math.min(height, math.floor(info.height / 2))
    width = math.max(width, 80)
    width = math.min(width, math.floor(info.width / 2))

    -- Fill buffer such that it covers entire window
    if height - #lines > 0 then
        vim.api.nvim_buf_set_lines(buf_h, 0, 0, false, u.make_n_lines(height - #lines, ''))
    end

    -- Add the lines to our buffer
    vim.api.nvim_buf_set_lines(buf_h, 0, 0, false, lines)

    -- Set bindings to exit
    closing_keys = closing_keys or {'<Esc>', '<CR>', '<Leader>'}
    for _, key in ipairs(closing_keys) do
        vim.api.nvim_buf_set_keymap(
            buf_h,
            'n',
            key,
            ':close<CR>',
            { silent = true, nowait = true, noremap = true }
        )
    end

    -- Render the window with the message
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

    -- Set color for window
    if ty == 'err' then
        vim.api.nvim_win_set_option(win, 'winhl', 'Normal:Error')
    end
end

return ui
