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

    --- Sort by id so we can ensure that we render in the same
    --- order every time, otherwise the table jumps around
    ---
    --- Lua's string comparison doesn't factor in the length
    --- of the string, so we have to provide a custom comparator
    ---
    --- @type string[]
    local ids = vim.deepcopy(vim.tbl_keys(opts.connections))
    table.sort(ids, function(a, b)
        if a:len() < b:len() then
            return true
        elseif a:len() > b:len() then
            return false
        else
            return a < b
        end
    end)

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
