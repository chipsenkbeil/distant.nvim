local core = require('distant-core')
local log = core.log
local state = core.state
local ui = core.ui
local utils = core.utils

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

    local manager = state.manager
    local client = state.client

    local msg = {}
    if client and manager then
        local connection = client.config.network.connection
        local destination = state.manager:connection_destination(connection)
        vim.list_extend(msg, {
            '= Client =',
            '',
            '* Connection = ' .. connection,
            '* Destination = ' .. destination,
        })
    else
        vim.list_extend(msg, {
            '= No Client =',
            '',
        })
    end

    vim.list_extend(msg, {
        '',
        '= Remote Files =',
        '',
    })
    vim.list_extend(msg, distant_buf_names)

    ui.show_msg(msg)
end
