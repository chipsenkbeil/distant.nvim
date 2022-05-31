local log = require('distant.log')
local state = require('distant.state')
local ui = require('distant.ui')
local utils = require('distant.utils')

--- Opens a new window to display session info
return function()
    log.trace('editor.show.session()')
    local indent = '    '
    local distant_buf_names = utils.filter_map(vim.api.nvim_list_bufs(), function(buf)
        local name = vim.api.nvim_buf_get_name(buf)
        if vim.startswith(name, 'distant://') then
            return indent .. '* ' .. string.sub(name, string.len('distant://') + 1)
        end
    end)

    local client = state.client

    local msg = {}
    if client and client:is_connected() then
        vim.list_extend(msg, {
            '= Client Connected =';
            '';
        })
    else
        vim.list_extend(msg, {
            '= Client Disconnected =';
            '';
        })
    end

    if client and client:details() then
        --- @type ClientDetails
        local details = client:details()

        local host, port
        if details.tcp then
            host = details.tcp.host
            port = tostring(details.tcp.port)

            table.insert(msg, indent .. ' * Type = "tcp"')
            table.insert(msg, indent .. ' * Host = "' .. host .. '"')
            table.insert(msg, indent .. ' * Port = "' .. port .. '"')
        elseif details.ssh then
            host = details.ssh.host or '???'
            port = tostring(details.ssh.port or 22)

            table.insert(msg, indent .. ' * Type = "ssh"')
            table.insert(msg, indent .. ' * Host = "' .. host .. '"')
            table.insert(msg, indent .. ' * Port = "' .. port .. '"')
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
