local ui = require('distant-core.ui')
local p = require('distant.ui.palette')

--- @return distant.core.ui.INode
local function ManagerConnection()
    local plugin = require('distant')
    local manager = plugin:manager()

    local function ListeningLine()
        local value
        if manager and manager:is_listening({}) then
            value = p.highlight 'yes'
        else
            value = p.warning 'no'
        end

        return {
            p.none '',
            p.Bold 'Listening',
            p.none '',
            value,
        }
    end

    local function PrivateLine()
        local value
        if plugin.settings.network.private then
            value = p.highlight 'yes'
        else
            value = p.warning 'no'
        end

        return {
            p.none '',
            p.Bold 'Private',
            p.none '',
            value,
        }
    end

    local function WindowsPipeLine()
        local text
        if manager and manager:network().windows_pipe then
            text = manager:network().windows_pipe
        end

        return {
            p.none '',
            p.Bold 'Windows Pipe',
            p.none '',
            text and p.highlight(text) or p.Comment '<default>',
        }
    end

    local function UnixSocketLine()
        local text
        if manager and manager:network().unix_socket then
            text = manager:network().unix_socket
        end

        return {
            p.none '',
            p.Bold 'Unix Socket',
            p.none '',
            text and p.highlight(text) or p.Comment '<default>',
        }
    end

    return ui.Node {
        ui.HlTextNode(p.heading 'Manager Connection'),
        ui.EmptyLine(),
        ui.Table {
            ListeningLine(),
            PrivateLine(),
            WindowsPipeLine(),
            UnixSocketLine(),
        },
        ui.EmptyLine(),
    }
end

--- @param opts {connections:distant.core.manager.ConnectionMap, selected?:distant.core.manager.ConnectionId}
--- @return distant.core.ui.INode
local function AvailableConnections(opts)
    local rows = {}

    -- Header row
    table.insert(rows, {
        p.none '',
        p.Bold 'ID',
        p.Bold 'Scheme',
        p.Bold 'Host',
        p.Bold 'Port',
    })

    local has_connections = not vim.tbl_isempty(opts.connections)
    local extra = {}

    --- Sort by id so we can ensure that we render in the same
    --- order every time, otherwise the table jumps around
    --- @type distant.core.manager.ConnectionId[]
    local ids = vim.deepcopy(vim.tbl_keys(opts.connections))
    table.sort(ids)

    for _, id in ipairs(ids) do
        local destination = opts.connections[id]

        --- @type string|number|nil
        local port_str = destination.port

        if type(port_str) == 'number' then
            port_str = tostring(port_str)
        else
            port_str = ''
        end

        local selected = ''
        if id == opts.selected then
            selected = '*'
        end

        table.insert(rows, {
            p.Bold(selected),
            p.muted(tostring(id)),
            p.highlight(destination.scheme or ''),
            p.highlight(destination.host),
            p.highlight(port_str),
        })

        extra[#rows] = {}
        extra[#rows] = {
            -- Return/Enter to switch
            ui.Keybind(
                '<CR>',
                'SWITCH_ACTIVE_CONNECTION',
                { id = id, destination = destination }
            ),

            -- Shift-i to expand information
            ui.Keybind(
                '<S-i>',
                'TOGGLE_EXPAND_CONNECTION',
                { id = id, destination = destination }
            ),

            -- Shift-k to kill
            ui.Keybind(
                '<S-k>',
                'KILL_CONNECTION',
                { id = id, destination = destination }
            ),
        }
    end

    return ui.Node {
        ui.HlTextNode(p.heading 'Available Connections'),
        ui.EmptyLine(),
        ui.When(has_connections, ui.Table(rows, extra)),
        ui.When(not has_connections, ui.CascadingStyleNode(
            { 'INDENT' },
            {
                ui.Text { 'N/A' },
            }
        )),
        ui.EmptyLine(),
    }
end


--- @param state distant.ui.State
--- @return distant.core.ui.INode
return function(state)
    return ui.Node {
        ui.EmptyLine(),
        ManagerConnection(),
        AvailableConnections({
            connections = state.info.connections.available,
            selected = state.info.connections.selected,
        }),
    }
end
