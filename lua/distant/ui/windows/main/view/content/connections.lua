local consts = require('distant.ui.windows.main.constants')
local p      = require('distant.ui.palette')
local ui     = require('distant-core.ui')

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

--- @param opts distant.plugin.ui.windows.main.state.info.Connections
--- @return distant.core.ui.INode
local function AvailableConnections(opts)
    local rows = {}

    -- Header row
    table.insert(rows, {
        p.none '',
        p.Bold 'ID',
        p.Bold 'Host',
    })

    local has_connections = not vim.tbl_isempty(opts.available)
    local extra = {}

    --- Sort by id so we can ensure that we render in the same
    --- order every time, otherwise the table jumps around
    --- @type distant.core.manager.ConnectionId[]
    local ids = vim.deepcopy(vim.tbl_keys(opts.available))
    table.sort(ids)

    for _, id in ipairs(ids) do
        local destination = opts.available[id]

        local selected = ''
        if id == opts.selected then
            selected = '*'
        end

        table.insert(rows, {
            p.Bold(selected),
            p.muted(tostring(id)),
            p.highlight(destination.host),
        })

        extra[#rows] = {}
        extra[#rows] = {
            -- Return/Enter to switch
            ui.Keybind(
                '<CR>',
                consts.EFFECTS.SWITCH_ACTIVE_CONNECTION,
                { id = id, destination = destination }
            ),

            -- Shift-i to expand information
            ui.Keybind(
                '<S-i>',
                consts.EFFECTS.TOGGLE_EXPAND_CONNECTION,
                { id = id, destination = destination }
            ),

            -- Shift-k to kill
            ui.Keybind(
                '<S-k>',
                consts.EFFECTS.KILL_CONNECTION,
                { id = id, destination = destination }
            ),

            -- When expanded, show it
            ui.When(opts.info[id] ~= nil, function()
                local info = opts.info[id]
                local lines = {
                    { p.muted 'Kind: ',    p.muted(info.destination.scheme) },
                    { p.muted 'Port: ',    p.muted(tostring(info.destination.port or '')) },
                    { p.muted 'Options: ', p.muted(tostring(info.options)) },
                }

                return ui.CascadingStyleNode(
                    { 'INDENT' },
                    { ui.Table(lines) }
                )
            end),
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

--- @return distant.core.ui.INode
local function ConnectionsFromSettings()
    local plugin = require('distant')
    local rows = {}
    local extra = {}

    -- Header row
    table.insert(rows, {
        p.none '',
        p.Bold 'Host',
        p.Bold 'Default',
    })

    --- List of servers from our settings, excluding default configuration
    --- @type string[]
    local servers = vim.tbl_filter(
        function(name) return name ~= '*' end,
        vim.tbl_keys(plugin.settings.servers)
    )
    table.sort(servers)

    for _, host in ipairs(servers) do
        local server = plugin:server_settings_for_host(host)

        -- If we have defaults, show them as JSON
        local default = not vim.tbl_isempty(server.launch.default)
            and vim.json.encode(server.launch.default)
            or ''

        table.insert(rows, {
            p.none '',
            p.highlight(host),
            p.highlight(default),
        })

        extra[#rows] = {}
        extra[#rows] = {
            -- Return/Enter to launch the server
            ui.Keybind(
                '<CR>',
                consts.EFFECTS.LAUNCH_SERVER,
                { host = host, settings = server }
            ),
        }
    end

    local has_servers = not vim.tbl_isempty(rows)

    return ui.Node {
        ui.HlTextNode(p.heading 'Available Servers'),
        ui.EmptyLine(),
        ui.When(has_servers, ui.Table(rows, extra)),
        ui.When(not has_servers, ui.CascadingStyleNode(
            { 'INDENT' },
            {
                ui.Text { 'N/A' },
            }
        )),
        ui.EmptyLine(),
    }
end

--- @param state distant.plugin.ui.windows.main.State
--- @return distant.core.ui.INode
return function(state)
    return ui.Node {
        ui.EmptyLine(),
        ManagerConnection(),
        AvailableConnections(state.info.connections),
        ConnectionsFromSettings(),
    }
end
