return {
    --- @param event distant.core.ui.window.EffectEvent
    ['CLOSE_WINDOW'] = function(event)
        local window = event.window

        --- @param state distant.plugin.ui.windows.metadata.State
        window:mutate_state(function(state)
            state.path = nil
            state.metadata = nil
        end)
        window:close()
    end,
}
