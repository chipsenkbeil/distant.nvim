--- @enum distant.plugin.ui.windows.main.Effect
local EFFECTS = {
    CLOSE_WINDOW                   = "CLOSE_WINDOW",
    KILL_CONNECTION                = "KILL_CONNECTION",
    LAUNCH_SERVER                  = "LAUNCH_SERVER",
    TOGGLE_EXPAND_CURRENT_SETTINGS = "TOGGLE_EXPAND_CURRENT_SETTINGS",
    RELOAD_TAB                     = "RELOAD_TAB",
    TOGGLE_EXPAND_CONNECTION       = "TOGGLE_EXPAND_CONNECTION",
    SET_VIEW                       = "SET_VIEW",
    SWITCH_ACTIVE_CONNECTION       = "SWITCH_ACTIVE_CONNECTION",
}

--- @enum distant.plugin.ui.windows.main.View
local VIEW = {
    CONNECTIONS = 'Connections',
    HELP = 'Help',
    SYSTEM_INFO = 'System Info',
}

return {
    EFFECTS = EFFECTS,
    VIEW = VIEW,
}
