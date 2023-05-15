local plugin      = require('distant')

local Destination = require('distant-core').Destination
local ui          = require('distant-core').ui
local Window      = require('distant-core').ui.Window

local Footer      = require('distant.ui.components.footer')
local Header      = require('distant.ui.components.header')
local Help        = require('distant.ui.components.help')
local Main        = require('distant.ui.components.main')
local Tabs        = require('distant.ui.components.tabs')

--- @param state distant.ui.State
--- @return distant.core.ui.Node
local function GlobalKeybinds(state)
    return ui.Node {
        ui.Keybind('?', 'TOGGLE_HELP', nil, true),
        ui.Keybind('q', 'CLOSE_WINDOW', nil, true),
        ui.Keybind('<Esc>', 'CLOSE_WINDOW', nil, true),
        ui.Keybind('r', 'RELOAD_TAB', { tab = state.view.current, force = true }, true),

        ui.Keybind('1', 'SET_VIEW', 'Connections', true),
        ui.Keybind('2', 'SET_VIEW', 'System Info', true),
    }
end

---@class distant.ui.State
local INITIAL_STATE = {
    --- @class distant.ui.state.Info
    info = {
        --- @class distant.ui.state.info.Connections
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
    --- @class distant.ui.state.View
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
    --- @class distant.ui.state.Header
    header = {
        title_prefix = '', -- for animation
    },
}

---@param state distant.ui.State
local function view(state)
    return ui.Node {
        GlobalKeybinds(state),
        Header(state),
        Tabs(state),
        ui.When(state.view.help.active, function()
            return Help(state)
        end),
        ui.When(not state.view.help.active, function()
            return Main(state)
        end),
        Footer(state),
    }
end

local __help_animation
--- @param window distant.core.ui.Window
local function help_animation(window)
    if not __help_animation then
        local help_command = ':help'
        local help_command_len = #help_command
        __help_animation = ui.animation({
            function(tick)
                ---@param state distant.ui.State
                window:mutate_state(function(state)
                    state.header.title_prefix = help_command:sub(help_command_len - tick, help_command_len)
                end)
            end,
            range = { 0, help_command_len },
            delay_ms = 80,
        })
    end

    return __help_animation()
end

local __ship_animation
--- @param window distant.core.ui.Window
local function ship_animation(window)
    if not __ship_animation then
        __ship_animation = ui.animation({
            function(tick)
                ---@param state distant.ui.State
                window:mutate_state(function(state)
                    state.view.help.ship_indentation = tick
                    if tick > -5 then
                        state.view.help.ship_exclamation = 'https://github.com/sponsors/chipsenkbeil'
                    elseif tick > -27 then
                        state.view.help.ship_exclamation = 'Sponsor distant.nvim development!'
                    else
                        state.view.help.ship_exclamation = ''
                    end
                end)
            end,
            range = { -35, 5 },
            delay_ms = 250,
        })
    end
    return __ship_animation()
end

--- @param event distant.core.ui.window.EffectEvent
local function toggle_help(event)
    local window = event.window

    ---@param state distant.ui.State
    window:mutate_state(function(state)
        state.view.help.active = not state.view.help.active
        if state.view.help.active then
            help_animation(window)
            ship_animation(window)
        end
    end)
end

--- @param event distant.core.ui.window.EffectEvent
local function toggle_expand_current_settings(event)
    local window = event.window

    ---@param state distant.ui.State
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
                ---@param state distant.ui.State
                window:mutate_state(function(state)
                    state.info.connections.available = connections
                end)
            end)
            ---@param state distant.ui.State
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

                ---@param state distant.ui.State
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

    --- @type distant.ui.State
    local state = event.state.get()

    -- If no info set for the connection, retrieve it and set it
    if not state.info.connections.info[id] then
        plugin:assert_manager():info({ connection = id }, function(err, info)
            assert(not err, tostring(err))

            --- @param state distant.ui.State
            event.state.mutate(function(state)
                state.info.connections.info[id] = info
            end)
        end)
    else
        -- Otherwise, clear the connection info to hide it
        --- @param state distant.ui.State
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

    ---@param state distant.ui.State
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

local window = Window:new({
    name = 'distant.nvim',
    filetype = 'distant',
    view = view,
    initial_state = INITIAL_STATE,
    effects = {
        ['CLOSE_WINDOW'] = function(event)
            event.window:close()
        end,
        ['SET_VIEW'] = set_view,
        ['TOGGLE_HELP'] = toggle_help,
        ['TOGGLE_EXPAND_CURRENT_SETTINGS'] = toggle_expand_current_settings,
        ['RELOAD_TAB'] = reload_tab,
        ['SWITCH_ACTIVE_CONNECTION'] = switch_active_connection,
        ['TOGGLE_EXPAND_CONNECTION'] = toggle_expand_connection,
        ['KILL_CONNECTION'] = kill_connection,
        ['LAUNCH_SERVER'] = launch_server,
    },
    winopts = {
        border = 'none',
        winhighlight = {
            'NormalFloat:DistantNormal',
        },
    },
})

plugin:on('connection:changed', function()
    window:dispatch('RELOAD_TAB', {
        tab = { 'Connections', 'System Info' },
        force = true,
    })
end)

return {
    window = window,
    set_view = function(view)
        set_view({ payload = view })
    end,
    set_sticky_cursor = function(tag)
        window:set_sticky_cursor(tag)
    end,
    --- @param name string
    --- @param payload? table
    dispatch = function(name, payload)
        window:dispatch(name, payload)
    end,
}
