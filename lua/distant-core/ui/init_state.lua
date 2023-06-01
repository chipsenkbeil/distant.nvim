--- Creates a new container for managing state.
--- @generic T: table
--- @param initial_state T
--- @param subscriber fun(state:T)
--- @return fun(current_state:T) mutate_state, fun():T get_state, fun(val:boolean) unsubscribe
return function(initial_state, subscriber)
    -- we do deepcopy to make sure instances of state containers doesn't mutate the initial state
    local state = vim.deepcopy(initial_state)
    local has_unsubscribed = false

    ---@param mutate_fn fun(current_state: table)
    return function(mutate_fn)
        mutate_fn(state)
        if not has_unsubscribed then
            subscriber(state)
        end
    end, function()
        return state
    end, function(val)
        has_unsubscribed = val
    end
end
