local log = require('distant.log')
local msg = require('distant.client.msg')
local state = require('distant.state')
local u = require('distant.utils')

--- Invokes callback with the library and session if available
--- via cb(err|nil, library|nil, session|nil), guaranteed that
--- either err is not nil or library + session are not nil
---
--- @param cb function `string|nil err, userdata|nil lib, userdata|nil session`
local function with_lib_and_session(cb)
    local lib = require('distant.lib')

    local first_time = not lib.is_loaded()
    lib.load(function(success, res)
        if not success then
            return cb(tostring(res) or 'Failed to load distant.lib')
        end

        -- Initialize logging of rust module
        if first_time then
            log.init_lib(res)
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
--- @param type string Type of request
--- @param obj table|nil If provided, will wrap a function on the current obj
---        instead of the active session
--- @param input_ty string|nil If provided, will be used to validate the input type
---        to the function, defaulting to 'function'
--- @return function
local function make_fn(params)
    vim.validate({
        name = {params.name, 'string', true},
        type = {params.type, 'string'},
        obj = {params.obj, 'table', true},
    })

    return function(opts, cb)
        if type(opts) == 'function' and cb == nil then
            cb = opts
            opts = {}
        end
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

        local session = state.session
        if not session then
            return cb('Session not initialized')
        end

        local name = params.name or params.type
        local async_method = (params.obj or session)[name]
        local async_method_type = type(async_method)
        if async_method_type ~= 'function' then
            return cb(string.format(
                'type(%s.%s) should be function, but got %s',
                params.obj and 'obj' or 'session', name, async_method_type
            ))
        end

        local client = state.load_client()
        client:send()
        f(params.obj or session, opts, function(success, res)
            if not success then
                return cb(tostring(res) or 'Unknown error occurred')
            end

            return cb(false, res)
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

local api = {}

api.append_file = make_fn('append_file')
api.append_file_text = make_fn('append_file_text')
api.copy = make_fn('copy')
api.create_dir = make_fn('create_dir')
api.exists = make_fn('exists')
api.metadata = make_fn('metadata')
api.read_dir = make_fn('read_dir')
api.read_file = make_fn('read_file')
api.read_file_text = make_fn('read_file_text')
api.remove = make_fn('remove')
api.rename = make_fn('rename')
api.spawn = make_fn('spawn')
api.spawn_lsp = make_fn('spawn_lsp')
api.spawn_wait = make_fn('spawn_wait')
api.system_info = make_fn('system_info')
api.watch = make_fn('watch')
api.write_file = make_fn('write_file')
api.write_file_text = make_fn('write_file_text')
api.unwatch = make_fn('unwatch')

return (function(names)
    local api = {}

    for _, name in ipairs(names) do
        api[name] = make_fn(name)

        -- Treat spawn and spawn_lsp specially as we want to wrap some of the
        -- process methods
        if name == 'spawn' or name == 'spawn_lsp' then
            local f = api[name]
            api[name] = function(opts, cb)
                local function wrap_proc(proc)
                    if not proc then
                        return
                    end

                    return {
                        id = proc.id,
                        is_active = function() return proc:is_active() end,
                        close_stdin = function() return proc:close_stdin() end,
                        write_stdin = make_fn('write_stdin', proc, 'string'),
                        read_stdout = make_fn('read_stdout', proc),
                        read_stderr = make_fn('read_stderr', proc),
                        status = make_fn('status', proc),
                        wait = make_fn('wait', proc),
                        output = make_fn('output', proc),
                        kill = make_fn('kill', proc),
                        abort = function() return proc:abort() end,
                    }
                end

                if not cb then
                    local err, proc = f(opts)
                    return err, wrap_proc(proc)
                else
                    f(opts, function(err, proc)
                        cb(err, wrap_proc(proc))
                    end)
                end
            end
        end
    end

    return api
end)({
    'append_file',
    'append_file_text',
    'copy',
    'create_dir',
    'exists',
    'metadata',
    'read_dir',
    'read_file',
    'read_file_text',
    'remove',
    'rename',
    'spawn',
    'spawn_lsp',
    'spawn_wait',
    'system_info',
    'watch',
    'write_file',
    'write_file_text',
    'unwatch',
})
