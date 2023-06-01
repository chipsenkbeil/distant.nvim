--- Makes it possible to create stateful animations by progressing from the start of a range to the end.
--- This is done in 'ticks', in accordance with the provided options.
---
--- @param opts {[1]:fun(tick:integer), range:{[1]:integer, [2]:integer}, delay_ms:integer, start_delay_ms:integer, iteration_delay_ms:integer}
--- @return fun():fun() start_animation # Function that will start the animation, returning another function that will cancel the animation
return function(opts)
    local animation_fn = opts[1]
    local start_tick, end_tick = opts.range[1], opts.range[2]
    local is_animating = false

    local function start_animation()
        if is_animating then
            return
        end
        local tick, start

        tick = function(current_tick)
            animation_fn(current_tick)
            if current_tick < end_tick then
                local delay_ms = opts.delay_ms

                --- @diagnostic disable-next-line:param-type-mismatch
                vim.defer_fn(function() tick(current_tick + 1) end, delay_ms)
            else
                is_animating = false
                if opts.iteration_delay_ms then
                    start(opts.iteration_delay_ms)
                end
            end
        end

        start = function(delay_ms)
            is_animating = true
            if delay_ms then
                --- @diagnostic disable-next-line:param-type-mismatch
                vim.defer_fn(function() tick(start_tick) end, delay_ms)
            else
                tick(start_tick)
            end
        end

        start(opts.start_delay_ms)

        local function cancel()
            is_animating = false
        end

        return cancel
    end

    return start_animation
end
