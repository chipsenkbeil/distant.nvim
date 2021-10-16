local log = require('distant.log')
local state = require('distant.state')
local ui = require('distant.ui')
local u = require('distant.utils')

--- Opens a new window to display session info
return function()
    log.trace('editor.show.session()')
    local indent = '    '
    local distant_buf_names = u.filter_map(vim.api.nvim_list_bufs(), function(buf)
        local name = vim.api.nvim_buf_get_name(buf)
        if vim.startswith(name, 'distant://') then
            return indent .. '* ' .. string.sub(name, string.len('distant://') + 1)
        end
    end)

    local session = state.session
    local msg = {}
    vim.list_extend(msg, {
        '= Session ' .. (session and 'Connected' or 'Disconnected') .. ' =';
        '';
    })

    if session then
        local details = session.details
        if details.tcp then
            table.insert(msg, indent .. ' * Type = "tcp"')
            table.insert(msg, indent .. ' * Address = "' .. details.tcp.addr .. '"')
            table.insert(msg, indent .. ' * Tag = "' .. details.tcp.tag .. '"')
        elseif details.socket then
            table.insert(msg, indent .. ' * Type = "socket"')
            table.insert(msg, indent .. ' * Path = "' .. details.socket.path .. '"')
            table.insert(msg, indent .. ' * Tag = "' .. details.socket.tag .. '"')
        elseif details.inmemory then
            table.insert(msg, indent .. ' * Type = "inmemory"')
            table.insert(msg, indent .. ' * Tag = "' .. details.inmemory.tag .. '"')
        else
            table.insert(msg, indent .. ' * Type = "unknown"')
        end
    end

    vim.list_extend(msg, {
        '';
        '= Remote Files =';
        '';
    })
    vim.list_extend(msg, distant_buf_names)

    ui.show_msg(msg)
end
