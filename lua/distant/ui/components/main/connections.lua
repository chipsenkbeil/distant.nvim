local Ui = require('distant-core.ui')
local p = require('distant.ui.palette')

--- @param opts {connections:table<string, distant.core.Destination>, selected?:string}
--- @return distant.core.ui.INode
local function AvailableConnections(opts)
    local rows = {}

    -- Header row
    table.insert(rows, {
        p.Bold '',
        p.Bold 'ID',
        p.Bold 'Scheme',
        p.Bold 'Host',
        p.Bold 'Port',
    })

    local has_connections = not vim.tbl_isempty(opts.connections)
    local extra = {}

    for id, destination in pairs(opts.connections) do
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
            p.muted(id),
            p.highlight(destination.scheme or ''),
            p.highlight(destination.host),
            p.highlight(port_str),
        })

        extra[#rows] = {}
        extra[#rows][1] = Ui.Keybind(
            '<CR>',
            'SWITCH_ACTIVE_CONNECTION',
            id
        )
    end

    return Ui.Node {
        Ui.HlTextNode(p.heading 'Available Connections'),
        Ui.EmptyLine(),
        Ui.When(has_connections, Ui.Table(rows, extra)),
        Ui.When(not has_connections, Ui.CascadingStyleNode(
            { 'INDENT' },
            {
                Ui.Text { 'N/A' },
            }
        )),
        Ui.EmptyLine(),
    }
end


--- @param state distant.ui.State
--- @return distant.core.ui.INode
return function(state)
    return Ui.Node {
        Ui.EmptyLine(),
        AvailableConnections({
            connections = state.info.connections.available,
            selected = state.info.connections.selected,
        }),
    }
end
