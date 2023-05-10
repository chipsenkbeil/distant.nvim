local events  = require('distant.events')
local fn      = require('distant.fn')

local Ui      = require('distant-core.ui')
local display = require('distant-core.ui.display')

local Header  = require('distant.ui.components.header')
local Help    = require('distant.ui.components.help')
local Main    = require('distant.ui.components.main')
local Tabs    = require('distant.ui.components.tabs')

--- @param state distant.ui.State
--- @return distant.core.ui.Node
local function GlobalKeybinds(state)
    return Ui.Node {
        Ui.Keybind('g?', 'TOGGLE_HELP', nil, true),
        Ui.Keybind('q', 'CLOSE_WINDOW', nil, true),
        Ui.Keybind('<Esc>', 'CLOSE_WINDOW', nil, true),
        Ui.Keybind('r', 'RELOAD_TAB', { tab = state.view.current, force = true }, true),

        Ui.Keybind('1', 'SET_VIEW', 'Connections', true),
        Ui.Keybind('2', 'SET_VIEW', 'System Info', true),
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

        ---@type distant.api.SystemInfoPayload|nil
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

local window = display.new_view_only_win('distant.nvim', 'distant')

window.view(
---@param state distant.ui.State
    function(state)
        return Ui.Node {
            GlobalKeybinds(state),
            Header(state),
            Tabs(state),
            Ui.When(state.view.is_showing_help, function()
                return Help(state)
            end),
            Ui.When(not state.view.is_showing_help, function()
                return Main(state)
            end),
        }
    end
)

--- @type fun(mutate_fn:fun(current_state:distant.ui.State)), fun():distant.ui.State
local mutate_state, get_state = window.state(INITIAL_STATE)

local help_animation
do
    local help_command = ':help'
    local help_command_len = #help_command
    help_animation = Ui.animation({
        function(tick)
            mutate_state(function(state)
                state.header.title_prefix = help_command:sub(help_command_len - tick, help_command_len)
            end)
        end,
        range = { 0, help_command_len },
        delay_ms = 80,
    })
end

local ship_animation = Ui.animation({
    function(tick)
        mutate_state(function(state)
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

local function toggle_help()
    mutate_state(function(state)
        state.view.is_showing_help = not state.view.is_showing_help
        if state.view.is_showing_help then
            help_animation()
            ship_animation()
        end
    end)
end

local function toggle_expand_current_settings()
    mutate_state(function(state)
        state.view.is_current_settings_expanded = not state.view.is_current_settings_expanded
    end)
end

--- @param event {payload:{tab:string|string[], force:boolean}}
local function reload_tab(event)
    local payload = event.payload

    -- If we got a single tab, convert it to a list of one
    local tabs = payload.tab
    if type(tabs) == 'string' then
        tabs = { tabs }
    end

    -- For each tab we want to refresh, do so
    for _, tab in ipairs(tabs) do
        if tab == 'Connections' then
            -- Update our available connections
            local plugin = require('distant.state')
            plugin:connections({}, function(err, connections)
                assert(not err, err)
                mutate_state(function(state)
                    state.info.connections.available = connections
                end)
            end)
            mutate_state(function(state)
                local id
                if plugin.client then
                    id = plugin.client:network().connection
                end
                state.info.connections.selected = id
            end)
        elseif tab == 'System Info' and fn.is_ready() then
            fn.cached_system_info({ reload = payload.force }, function(err, system_info)
                assert(not err, tostring(err))
                assert(system_info)
                mutate_state(function(state)
                    state.info.system_info = system_info
                end)
            end)
        end
    end
end

--- @param event {payload:string}
local function switch_active_connection(event)
    -- Update our active client connection
    local plugin = require('distant.state')
    local id = event.payload

    -- Load our manager and refresh the connections
    -- before attempting to assign the client
    plugin:connections({}, function(err, _)
        assert(not err, err)
        if plugin.manager then
            plugin.client = assert(
                plugin.manager:client(id),
                'Neovim manager lost track of client'
            )
            events.emit_connection_changed(plugin.client)
        end
    end)
end

--- @param event {payload:string}
local function set_view(event)
    local view = event.payload
    mutate_state(function(state)
        state.view.current = view
        state.view.has_changed = true
    end)
    if window.is_open() then
        local cursor_line = window.get_cursor()[1]
        if cursor_line > (window.get_win_config().height * 0.75) then
            window.set_sticky_cursor('tabs')
        end
    end
end

local effects = {
    ['CLOSE_WINDOW'] = window.close,
    ['SET_VIEW'] = set_view,
    ['TOGGLE_HELP'] = toggle_help,
    ['TOGGLE_EXPAND_CURRENT_SETTINGS'] = toggle_expand_current_settings,
    ['RELOAD_TAB'] = reload_tab,
    ['SWITCH_ACTIVE_CONNECTION'] = switch_active_connection,
}

window.init({
    effects = effects,
    border = 'none',
    winhighlight = {
        'NormalFloat:DistantNormal',
    },
})

events.on_connection_changed(function()
    reload_tab({
        payload = {
            tab = 'Connections',
            force = false,
        }
    })

    reload_tab({
        payload = {
            tab = 'System Info',
            force = true,
        }
    })
end)

return {
    window = window,
    set_view = function(view)
        set_view({ payload = view })
    end,
    set_sticky_cursor = function(tag)
        window.set_sticky_cursor(tag)
    end,
    --- @param name string
    --- @param payload? table
    dispatch = function(name, payload)
        window.dispatch(name, payload)
    end,
}
