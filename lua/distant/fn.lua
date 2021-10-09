local state = require('distant.state')
local u = require('distant.utils')

--- Invokes callback with the library and session if available
--- via cb(err|nil, library|nil, session|nil), guaranteed that
--- either err is not nil or library + session are not nil
---
--- @param cb function `string|nil err, userdata|nil lib, userdata|nil session`
local function with_lib_and_session(cb)
    local lib = require('distant.lib')

    lib.load(function(success, res)
        if not success then
            return cb(tostring(res) or 'Failed to load distant.lib')
        end

        if state.session then
            return cb(nil, res, state.session)
        else
            return cb('Session not initialized')
        end
    end)
end

--- Creates a function that when invoked will synchronously or asynchronously
--- perform the underlying operation. If a callback is provided, this is
--- asynchronous and will trigger the callback when finished in the form of
--- `function(err|nil, data|nil)`. If no callback is provided, then this is
--- will be invoked synchronously and return `err|nil, data|nil`
---
--- @param name string Name of the function on the session to call
--- @return function
local function make_fn(name)
    vim.validate({name = {name, 'string'}})
    if not vim.endswith(name, '_async') then
        name = name .. '_async'
    end

    return function(opts, cb)
        if not opts then
            opts = {}
        end

        -- If no callback provided, then this is synchronous
        local rx
        if not cb then
            cb, rx = u.oneshot_channel(
                opts.timeout or state.settings.max_timeout,
                opts.interval or state.settings.timeout_interval
            )
        end

        vim.validate({
            opts = {opts, 'table'},
            cb = {cb, 'function'},
        })

        with_lib_and_session(function(err, lib, session)
            if err then
                return cb(err)
            end

            local async_method = session[name]
            local async_method_type = type(async_method)
            if async_method_type ~= 'function' then
                return cb(string.format(
                    'type(session.%s) should be function, but got %s',
                    name, async_method_type
                ))
            end

            local f = lib.utils.nvim_wrap_async(async_method)
            f(session, opts, function(success, res)
                if not success then
                    return cb(tostring(res) or 'Unknown error occurred')
                end

                return cb(nil, res)
            end)
        end)

        -- If we have a receiver, this indicates that we are synchronous
        if rx then
            local err1, err2, result = rx()
            return err1 or err2, result
        end
    end
end

-------------------------------------------------------------------------------
-- FUNCTION API
-------------------------------------------------------------------------------

return (function(names)
    local api = {}

    for _, name in ipairs(names) do
        api[name] = make_fn(name)
    end

    return api
end)({
    'append_file',
    'append_file_text',
    'copy',
    'dir_list',
    'exists',
    'metadata',
    'mkdir',
    'read_file',
    'read_file_text',
    'remove',
    'rename',
    'spawn',
    'spawn_wait',
    'system_info',
    'write_file',
    'write_file_text',
})
