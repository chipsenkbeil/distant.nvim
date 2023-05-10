local Ui = require('distant-core.ui')
local p = require('distant.ui.palette')

--- @return distant.core.ui.INode
local function ManagerConnection()
    local plugin = require('distant.state')

    local function ListeningLine()
        local value
        if plugin.manager and plugin.manager:is_listening({}) then
            value = p.highlight 'yes'
        else
            value = p.warning 'no'
        end

        return { p.Bold '', p.Bold 'Listening', value }
    end

    local function PrivateLine()
        local value
        if plugin.settings.network.private then
            value = p.highlight 'yes'
        else
            value = p.warning 'no'
        end

        return { p.Bold '', p.Bold 'Private', value }
    end

    local function WindowsPipeLine()
        if plugin.manager and plugin.manager:network().windows_pipe then
            return {
                p.Bold '',
                p.Bold 'Windows Pipe',
                p.highlight(plugin.manager:network().windows_pipe),
            }
        end
    end

    local function UnixSocketLine()
        if plugin.manager and plugin.manager:network().unix_socket then
            return {
                p.Bold '',
                p.Bold 'Unix Socket',
                p.highlight(plugin.manager:network().unix_socket),
            }
        end
    end

    return Ui.Node {
        Ui.HlTextNode(p.heading 'Manager Connection'),
        Ui.EmptyLine(),
        Ui.Table(vim.tbl_filter(function(line) return line ~= nil end, {
            ListeningLine(),
            PrivateLine(),
            WindowsPipeLine(),
            UnixSocketLine(),
        })),
        Ui.EmptyLine(),
    }
end

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
            { id = id, destination = destination }
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
        ManagerConnection(),
        AvailableConnections({
            connections = state.info.connections.available,
            selected = state.info.connections.selected,
        }),
    }
end
