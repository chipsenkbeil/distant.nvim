local Destination = require('distant-core').Destination
local plugin      = require('distant')

--- @param event distant.core.ui.window.EffectEvent
local function toggle_expand_current_settings(event)
    local window = event.window

    ---@param state distant.plugin.ui.windows.main.State
    window:mutate_state(function(state)
        state.view.is_current_settings_expanded = not state.view.is_current_settings_expanded
    end)
end

--- @param event distant.core.ui.window.EffectEvent
local function reload_tab(event)
    --- @type {tab:string|string[], force:boolean}
    local payload = event.payload
    local window = event.window

    -- If we got a single tab, convert it to a list of one
    local tabs = payload.tab
    if type(tabs) == 'string' then
        tabs = { tabs }
    end

    -- For each tab we want to refresh, do so
    for _, tab in ipairs(tabs) do
        if tab == 'Connections' then
            -- Update our available connections
            plugin:connections({}, function(err, connections)
                assert(not err, err)
                ---@param state distant.plugin.ui.windows.main.State
                window:mutate_state(function(state)
                    state.info.connections.available = connections
                end)
            end)
            ---@param state distant.plugin.ui.windows.main.State
            window:mutate_state(function(state)
                local id
                local client = plugin:client()
                if client then
                    id = client:connection()
                end
                state.info.connections.selected = id
            end)
        elseif tab == 'System Info' and plugin.api.is_ready() then
            plugin.api.cached_system_info({ reload = payload.force }, function(err, system_info)
                assert(not err, tostring(err))
                assert(system_info)

                ---@param state distant.plugin.ui.windows.main.State
                window:mutate_state(function(state)
                    state.info.system_info = system_info
                end)
            end)
        end
    end
end

--- @param event distant.core.ui.window.EffectEvent
local function toggle_expand_connection(event)
    --- @type {id:distant.core.manager.ConnectionId, destination:distant.core.Destination}
    local payload = event.payload
    local id = payload.id

    --- @type distant.plugin.ui.windows.main.State
    local state = event.state.get()

    -- If no info set for the connection, retrieve it and set it
    if not state.info.connections.info[id] then
        plugin:assert_manager():info({ connection = id }, function(err, info)
            assert(not err, tostring(err))

            --- @param state distant.plugin.ui.windows.main.State
            event.state.mutate(function(state)
                state.info.connections.info[id] = info
            end)
        end)
    else
        -- Otherwise, clear the connection info to hide it
        --- @param state distant.plugin.ui.windows.main.State
        event.state.mutate(function(state)
            state.info.connections.info[id] = nil
        end)
    end
end

--- @param event distant.core.ui.window.EffectEvent
local function kill_connection(event)
    --- @type {id:distant.core.manager.ConnectionId, destination:distant.core.Destination}
    local payload = event.payload
    local id = payload.id
    local window = event.window

    vim.ui.input({ prompt = 'Are you sure you want to kill this connection? [y/N]' }, function(input)
        input = string.lower(vim.trim(input or ''))

        if input == 'y' or input == 'yes' then
            plugin:assert_manager():kill({ connection = id }, function(err, ok)
                assert(not err, tostring(err))

                -- TODO: If we offer toasts, do so
                window:dispatch('RELOAD_TAB', {
                    tab = { 'Connections', 'System Info' },
                    force = false,
                })
            end)
        end
    end)
end

--- @param event distant.core.ui.window.EffectEvent
local function switch_active_connection(event)
    --- @type {id:distant.core.manager.ConnectionId, destination:distant.core.Destination}
    local payload = event.payload
    local id = payload.id

    -- Load our manager and refresh the connections
    -- before attempting to assign the client
    plugin:connections({}, function(err, _)
        assert(not err, err)
        plugin:set_active_client_id(id)
    end)
end

--- @param event distant.core.ui.window.EffectEvent
local function launch_server(event)
    --- @type {host:string, settings:distant.plugin.settings.ServerSettings}
    local payload = event.payload
    local host = payload.host
    local settings = payload.settings

    vim.ui.input({
        prompt = ('Are you sure you want to launch %s? [y/N]'):format(host),
    }, function(input)
        input = string.lower(vim.trim(input or ''))

        if input == 'y' or input == 'yes' then
            plugin:launch({ destination = Destination:new({ host = host }) }, function(err, _)
                assert(not err, tostring(err))

                -- TODO: Update connections to reflect! And if we offer toasts, do so
            end)
        end
    end)
end

--- @param event distant.core.ui.window.EffectEvent
local function set_view(event)
    --- @type string
    local view = event.payload
    local window = event.window

    ---@param state distant.plugin.ui.windows.main.State
    window:mutate_state(function(state)
        state.view.current = view
        state.view.has_changed = true
    end)
    if window:is_open() then
        local cursor_line = window:get_cursor()[1]
        if cursor_line > (window:win_config().height * 0.75) then
            window:set_sticky_cursor('tabs')
        end
    end
end

return {
    ['CLOSE_WINDOW'] = function(event)
        event.window:close()
    end,
    ['SET_VIEW'] = set_view,
    ['TOGGLE_EXPAND_CURRENT_SETTINGS'] = toggle_expand_current_settings,
    ['RELOAD_TAB'] = reload_tab,
    ['SWITCH_ACTIVE_CONNECTION'] = switch_active_connection,
    ['TOGGLE_EXPAND_CONNECTION'] = toggle_expand_connection,
    ['KILL_CONNECTION'] = kill_connection,
    ['LAUNCH_SERVER'] = launch_server,
}
