local u = require('distant.internal.utils')

local ui = {}

--- Displays a popup window with the provided message
---
--- @param msg string|table contains the message to display
--- @param ty string The type of window to show ('msg', 'err')
--- @param width number width of the window (optional)
--- @param height number height of the window (optional)
--- @return number handle returns the handle of the buffer containing the message
ui.show_msg = function(msg, ty, width, height, closing_keys)
    local buf_h = vim.api.nvim_create_buf(false, true)
    assert(buf_h ~= 0, 'Failed to create buffer for msg')

    local info = vim.api.nvim_list_uis()[1]

    -- Get lines as a list
    if type(msg) == 'table' then
        msg = table.concat(msg, '\n')
    end
    local lines = u.filter_map(vim.split(msg, '\n', true), function(line)
        if line ~= nil then
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
        vim.api.nvim_buf_set_lines(buf_h, 0, 1, false, u.make_n_lines(height - #lines, ''))
    end

    -- Add the lines to our buffer
    vim.api.nvim_buf_set_lines(buf_h, 0, 1, false, lines)

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

    return buf_h
end

return ui
