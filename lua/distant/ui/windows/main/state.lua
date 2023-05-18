--- @class distant.ui.windows.main.State
local INITIAL_STATE = {
    --- @class distant.ui.windows.main.state.Info
    info = {
        --- @class distant.ui.windows.main.state.info.Connections
        connections = {
            --- @type distant.core.manager.ConnectionId|nil
            selected = nil,
            --- @type distant.core.manager.ConnectionMap
            available = {},
            --- @type table<distant.core.manager.ConnectionId, distant.core.manager.Info>
            info = {},
        },
        ---@type distant.core.api.SystemInfoPayload|nil
        system_info = nil,
    },
    --- @class distant.ui.windows.main.state.View
    view = {
        --- Which view to display
        current = 'Connections',

        --- Help-specific view state
        help = {
            --- Show help
            active = false,
            --- Show settings within help
            is_current_settings_expanded = false,
            --- Display extra help tip if false
            has_changed = false,
            --- Ship position
            ship_indentation = 0,
            --- Ship ???
            ship_exclamation = '',
        },
    },
    --- @class distant.ui.windows.main.state.Header
    header = {
        title_prefix = '', -- for animation
    },
}

return INITIAL_STATE
