--- @class distant.plugin.ui.windows.main.State
local INITIAL_STATE = {
    --- @class distant.plugin.ui.windows.main.state.Info
    info = {
        --- @class distant.plugin.ui.windows.main.state.info.Connections
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
    --- @class distant.plugin.ui.windows.main.state.View
    view = {
        --- Which view to display
        current = 'Connections',

        --- Indication that the view has been altered
        has_changed = false,

        --- Help-specific view state
        help = {
            --- Show help
            active = false,
            --- Show settings within help
            is_current_settings_expanded = false,
        },
    },
    --- @class distant.plugin.ui.windows.main.state.Header
    header = {
        title_prefix = '', -- for animation
    },
}

return INITIAL_STATE
