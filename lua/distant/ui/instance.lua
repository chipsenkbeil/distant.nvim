local plugin = require('distant')

local ui     = require('distant-core.ui')
local Window = require('distant-core.ui').Window

local Footer = require('distant.ui.components.footer')
local Header = require('distant.ui.components.header')
local Help   = require('distant.ui.components.help')
local Main   = require('distant.ui.components.main')
local Tabs   = require('distant.ui.components.tabs')

--- @param state distant.ui.State
--- @return distant.core.ui.Node
local function GlobalKeybinds(state)
    return ui.Node {
        ui.Keybind('g?', 'TOGGLE_HELP', nil, true),
        ui.Keybind('q', 'CLOSE_WINDOW', nil, true),
        ui.Keybind('<Esc>', 'CLOSE_WINDOW', nil, true),
        ui.Keybind('r', 'RELOAD_TAB', { tab = state.view.current, force = true }, true),

        ui.Keybind('1', 'SET_VIEW', 'Connections', true),
        ui.Keybind('2', 'SET_VIEW', 'System Info', true),
    }
end

---@class distant.ui.State
local INITIAL_STATE = {
    info = {
        connections = {
            --- @type string|nil
            selected = nil,
            --- @type table<string, distant.core.Destination>
            available = {},
        },
        ---@type distant.core.api.SystemInfoPayload|nil
        system_info = nil,
    },
    view = {
        is_showing_help = false,
        is_current_settings_expanded = false,
        language_filter = nil,
        current = 'Connections',
        has_changed = false,
        ship_indentation = 0,
        ship_exclamation = '',
    },
    header = {
        title_prefix = '', -- for animation
    },
}

---@param state distant.ui.State
local function render(state)
    return ui.Node {
        GlobalKeybinds(state),
        Header(state),
        Tabs(state),
        ui.When(state.view.is_showing_help, function()
            return Help(state)
        end),
        ui.When(not state.view.is_showing_help, function()
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
                    state.view.ship_indentation = tick
                    if tick > -5 then
                        state.view.ship_exclamation = 'https://github.com/sponsors/chipsenkbeil'
                    elseif tick > -27 then
                        state.view.ship_exclamation = 'Sponsor distant.nvim development!'
                    else
                        state.view.ship_exclamation = ''
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
        state.view.is_showing_help = not state.view.is_showing_help
        if state.view.is_showing_help then
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
        elseif tab == 'System Info' and plugin.fn.is_ready() then
            plugin.fn.cached_system_info({ reload = payload.force }, function(err, system_info)
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
local function switch_active_connection(event)
    --- @type {id:string, destination:distant.core.Destination}
    local payload = event.payload
    local id = payload.id

    -- Load our manager and refresh the connections
    -- before attempting to assign the client
    plugin:connections({}, function(err, _)
        assert(not err, err)
        plugin:set_active_client(id)
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
    view = render,
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
