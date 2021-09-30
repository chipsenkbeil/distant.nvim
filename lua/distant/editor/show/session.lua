local log = require('distant.log')
local s = require('distant.state')
local ui = require('distant.ui')
local u = require('distant.utils')

--- Opens a new window to display session info
return function()
    log.trace('editor.show.session()')
    local indent = '    '
    local session = s.session()
    local distant_buf_names = u.filter_map(vim.api.nvim_list_bufs(), function(buf)
        local name = vim.api.nvim_buf_get_name(buf)
        if vim.startswith(name, 'distant://') then
            return indent .. '* ' .. string.sub(name, string.len('distant://') + 1)
        end
    end)

    local session_info = {'Disconnected'}
    if session ~= nil then
        session_info = {
            indent .. '* Host = "' .. session.host .. '"';
            indent .. '* Port = "' .. session.port .. '"';
            indent .. '* Key = "' .. session.key .. '"';
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
