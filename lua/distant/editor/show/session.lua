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

    local msg = {}
    vim.list_extend(msg, {
        '= Session =';
        '';
    })

    local session = state.session
    if session then
        table.insert(msg, indent .. ' * Tag = "' .. session.connection_tag .. '"')
    else
        table.insert(msg, 'Disconnected')
    end

    vim.list_extend(msg, {
        '';
        '= Remote Files =';
        '';
    })
    vim.list_extend(msg, distant_buf_names)

    ui.show_msg(msg)
end
