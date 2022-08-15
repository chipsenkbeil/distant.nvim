local log   = require('distant.log')
local utils = require('distant.utils')

--- Represents communication handler
--- @class Comm
--- @field __auth AuthHandler #Authentication-based handlers
--- @field __state CommInternalState
--- @field __settings CommInternalSettings
local Comm = {}
Comm.__index = Comm

--- @class AuthHandler
--- @field on_authenticate? fun(msg:AuthHandlerMsg):string[]
--- @field on_verify_host? fun(host:string):boolean
--- @field on_info? fun(text:string)
--- @field on_error? fun(err:string)
--- @field on_unknown? fun(x:any)

--- @class AuthHandlerMsg
--- @field username? string
--- @field instructions? string
--- @field prompts {prompt:string, echo:boolean}[]

--- @return AuthHandler
local function make_auth_handler()
    return {
        --- @param msg AuthHandlerMsg
        --- @return string[]
        on_authenticate = function(msg)
            if msg.username then
                print('Authentication for ' .. msg.username)
            end
            if msg.instructions then
                print(msg.instructions)
            end

            local answers = {}
            for _, p in ipairs(msg.prompts) do
                if p.echo then
                    table.insert(answers, vim.fn.input(p.prompt))
                else
                    table.insert(answers, vim.fn.inputsecret(p.prompt))
                end
            end
            return answers
        end,

        --- @param host string
        --- @return boolean
        on_verify_host = function(host)
            local answer = vim.fn.input(string.format('%s\nEnter [y/N]> ', host))
            return answer == 'y' or answer == 'Y' or answer == 'yes' or answer == 'YES'
        end,

        --- @param text string
        on_info = function(text)
            print(text)
        end,

        --- @param err string
        on_error = function(err)
            log.fmt_error('Authentication error: %s', err)
        end,

        --- @param x any
        on_unknown = function(x)
            log.fmt_error('Unknown authentication event received: %s', x)
        end,
    }
end

--- @class CommInternalState
--- @field handle? JobHandle
--- @field callbacks table<string, InternalCallback>

--- @class CommInternalCallback
--- @field callback fun(payload:table) @Invoked with payload from received event
--- @field multi boolean @If true, will not clear the callback after first invocation
--- @field stop fun() @When called, will stop the callback from being invoked and clear it

--- @class CommNewOpts
--- @field auth? AuthHandler
--- @field bin? string
--- @field timeout? number
--- @field interval? number

--- Creates a new instance of our comm that is not yet connected
--- @param handle JobHandle #Handle to the underlying process
--- @param opts? CommNewOpts Options for use with our comm
--- @return Comm
function Comm:new(handle, opts)
    opts = opts or {}

    local instance = {}
    setmetatable(instance, Comm)

    instance.__auth = vim.tbl_deep_extend(
        'keep',
        opts.auth or {},
        make_auth_handler()
    )

    instance.__state = {
        handle = handle;
        callbacks = {};
    }

    return instance
end

--- Whether or not the comm is connected to a remote server
--- @return boolean
function Comm:is_connected()
    return self.__state.handle ~= nil and self.__state.handle:running()
end

--- Stops an instance of distant if running by killing the process
--- and resetting state
function Comm:stop()
    if self.__state.handle ~= nil then
        self.__state.handle.stop()
    end
    self.__state.handle = nil
    self.__state.callbacks = {}
end

--- @class CommMsg
--- @field type string
--- @field data table

--- @alias OneOrMoreMsgs CommMsg|CommMsg[]

--- @class SendOpts
--- @field unaltered? boolean @when true, the callback will not be wrapped in the situation where there is
---                           a single request payload entry to then return a single response payload entry
--- @field multi? boolean @when true, the callback may be triggered multiple times and will not be cleared
---                       within the Comm upon receiving an event. Instead, a function is returned that will
---                       be called when we want to stop receiving events whose origin is this message

--- Send one or more messages to the remote machine, invoking the provided callback with the
--- response once it is received
---
--- @param msgs OneOrMoreMsgs
--- @param opts? SendOpts
--- @param cb fun(data:table, stop:fun()|nil)
function Comm:send(msgs, opts, cb)
    if type(cb) ~= 'function' then
        cb = opts
        opts = {}
    end

    if not opts then
        opts = {}
    end

    log.fmt_trace('Comm:send(%s, %s, _)', msgs, opts)
    assert(self:is_connected(), 'Comm is not connected!')

    local payload = msgs
    if not vim.tbl_islist(payload) then
        payload = { payload }
    end

    -- Build a full message that wraps the provided message as the payload and
    -- includes an id that our comm uses when relaying a response for the
    -- callback to process
    local full_msg = {
        id = utils.next_id();
        payload = payload;
    }

    -- Store a callback based on our payload length
    --
    -- If we send a single message, then we expect a single message back in the
    -- payload's entry and want to adjust the payload as such
    --
    -- Otherwise, we leave as is and get a list as our payload
    local callback = cb
    if #payload == 1 and not opts.unaltered then
        callback = function(entries, stop)
            cb(entries[1], stop)
        end
    end
    self.__state.callbacks[full_msg.id] = {
        callback = callback,
        multi = opts.multi,
        stop = function()
            self.__state.callbacks[full_msg.id] = nil
        end
    }

    local json = utils.compress(vim.fn.json_encode(full_msg)) .. '\n'
    self.__state.handle.write(json)
end

--- Send one or more messages to the remote machine and wait synchronously for the result
--- up to `timeout` milliseconds, checking every `interval` milliseconds for
--- a result (default timeout = 1000, interval = 200)
--
--- @param msgs OneOrMoreMsgs
--- @param opts? table
--- @return table
function Comm:send_wait(msgs, opts)
    opts = opts or {}
    log.fmt_trace('Comm:send_wait(%s, %s)', msgs, opts)
    local tx, rx = utils.oneshot_channel(
        opts.timeout or self.__settings.timeout,
        opts.interval or self.__settings.interval
    )

    self:send(msgs, opts, function(data)
        tx(data)
    end)

    return rx()
end

--- Send one or more messages to the remote machine, wait synchronously for the result up
--- to `timeout` milliseconds, checking every `interval` milliseconds for a
--- result (default timeout = 1000, interval = 200), and report an error if not okay
---
--- @param msgs OneOrMoreMsgs
--- @param opts? table
--- @return table|nil
function Comm:send_wait_ok(msgs, opts)
    opts = opts or {}
    log.fmt_trace('Comm:send_wait_ok(%s, %s)', msgs, opts)
    local timeout = opts.timeout or self.__settings.timeout
    local result = self:send_wait(msgs, opts)
    if result == nil then
        log.fmt_error('Max timeout (%s) reached waiting for result', timeout)
    elseif result.type == 'error' then
        log.fmt_error('Call failed: %s', vim.inspect(result.data.description))
    else
        return result
    end
end

--- Primary event handler, routing received events to the corresponding callbacks
function Comm:__handler(msg)
    assert(type(msg) == 'table', 'msg must be a table')
    log.fmt_trace('Comm:__handler(%s)', msg)

    -- {"id": ..., "origin_id": ..., "payload": ...}
    local origin_id = msg.origin_id
    local payload = msg.payload

    -- If no payload, nothing to process for a callback
    if not payload then
        return
    end

    --- @type fun(payload:table, stop:fun()|nil)|nil
    local cb

    --- @type fun()|nil
    local stop

    -- Look up our callback and, if it exists, invoke it
    if origin_id ~= nil and origin_id ~= vim.NIL then
        local cb_state = self.__state.callbacks[origin_id]
        if cb_state ~= nil then
            cb = cb_state.callback
            stop = cb_state.stop

            -- If we are not marked to receive multiple events, clear our callback
            -- and set the stop function to nil since we don't want it to exist
            if not cb_state.multi then
                self.__state.callbacks[origin_id] = nil
                stop = nil
            end
        end
    end

    if cb then
        return cb(payload, stop)
    else
        log.fmt_warn('Discarding message with origin %s as no callback exists', origin_id)
    end
end

--- Authentication event handler
--- @overload fun(msg:table, reply:fun(msg:table)):boolean
--- @param msg table
--- @param reply fun(msg:table)
--- @param auth? AuthHandler
--- @return boolean #true if okay, otherwise false
function Comm:__auth_handler(msg, reply, auth)
    local type = msg.type

    --- @type AuthHandler
    auth = vim.tbl_deep_extend('keep', auth or {}, self.__auth)

    if type == 'challenge' then
        reply({
            type = 'challenge',
            answers = auth.on_authenticate(msg)
        })
        return true
    elseif type == 'info' then
        auth.on_info(msg.text)
        return true
    elseif type == 'verify' then
        reply({
            type = 'verify',
            answer = auth.on_verify_host(msg.host)
        })
        return true
    elseif type == 'error' then
        auth.on_error(vim.inspect(msg))
        return false
    else
        auth.on_unknown(msg)
        return false
    end
end

--- @param msg {type:string}
--- @return boolean
function Comm:__is_auth_msg(msg)
    return msg and type(msg.type) == 'string' and vim.tbl_contains({
        'challenge',
        'verify',
        'info',
        'error',
    }, msg.type)
end

return Comm
