local AuthHandler      = require('distant-core.auth.handler')
local builder          = require('distant-core.builder')
local log              = require('distant-core.log')
local utils            = require('distant-core.utils')

local DEFAULT_TIMEOUT  = 15000
local DEFAULT_INTERVAL = 100

--- Represents a JSON-formatted distant api transport.
--- @class DistantApiTransport
--- @field config {binary:string, network:DistantClientNetwork, timeout?:number, interval?:number}
--- @field __state DistantApiTransportState
local M                = {}
M.__index              = M

--- @class DistantApiTransportState
--- @field authenticated boolean True if authenticated and ready to send messages
--- @field queue string[] Queue of outgoing json messages
--- @field handle? JobHandle
--- @field callbacks table<string, DistantApiCallback>

--- @class DistantApiCallback
--- @field callback fun(payload:table) #Invoked with payload from received event
--- @field multi boolean #If true, will not clear the callback after first invocation
--- @field stop fun() #When called, will stop the callback from being invoked and clear it

--- @class DistantApiMsg
--- @field type string
--- @field data table

--- Creates a new instance of our repl that wraps a job
--- @param opts {binary:string, network:DistantClientNetwork, timeout?:number, interval?:number}
--- @return DistantApiTransport
function M:new(opts)
    opts = opts or {}

    local instance = {}
    setmetatable(instance, M)
    instance.config = opts
    assert(instance.config.binary, 'Transport missing binary')
    assert(instance.config.network, 'Transport missing network')
    instance.config.timeout = instance.config.timeout or DEFAULT_TIMEOUT
    instance.config.interval = instance.config.interval or DEFAULT_INTERVAL

    instance.__state = {
        authenticated = false,
        queue = {},
        handle = nil,
        callbacks = {},
    }

    return instance
end

--- Whether or not the repl is running
--- @return boolean
function M:is_running()
    return self.__state.handle ~= nil and self.__state.handle:running()
end

--- Starts the repl if it is not already running
--- @param cb? fun(code:number) Optional callback when the repl exits
function M:start(cb)
    if not self:is_running() then
        -- Assign a fresh authentication handler
        local auth = AuthHandler:new()

        local cmd = builder.api():set_from_tbl(self.config.network):as_list()
        table.insert(cmd, 1, self.config.binary)

        local handle
        handle = utils.job_start(cmd, {
            on_success = function()
                self:stop()
                if type(cb) == 'function' then
                    cb(0)
                end
            end,
            on_failure = function(code)
                self:stop()
                if type(cb) == 'function' then
                    cb(code)
                end
            end,
            on_stdout_line = function(line)
                if line ~= nil and line ~= "" then
                    --- @type boolean,table|nil
                    local success, msg = pcall(vim.fn.json_decode, line)

                    -- Quit if the decoding failed or we didn't get a msg
                    if not success then
                        log.fmt_error('Failed to decode to json: "%s"', line)
                        return
                    end

                    if not msg or type(msg.type) ~= 'string' then
                        log.fmt_error('Invalid msg: %s', msg)
                        return
                    end

                    -- Check if we are processing an authentication msg
                    -- or an API message
                    if auth:is_auth_request(msg) then
                        --- @diagnostic disable-next-line:redefined-local
                        auth:handle_request(msg, function(msg)
                            handle.write(utils.compress(vim.fn.json_encode(msg)) .. '\n')
                        end)
                        self.__state.authenticated = auth.finished

                        if auth.finished then
                            for _, json in ipairs(self.__state.queue) do
                                self.__state.handle.write(json)
                            end
                            self.__state.queue = {}
                        end
                    else
                        self:__handler(msg)
                    end
                end
            end,
            on_stderr_line = function(line)
                if line ~= nil and line ~= "" then
                    log.error(line)
                end
            end
        })
        self.__state.handle = handle
    end
end

--- Stops an instance of distant if running by killing the process
--- and resetting state
function M:stop()
    if self.__state.handle ~= nil and self.__state.handle:running() then
        self.__state.handle.stop()
    end
    self.__state.authenticated = false
    self.__state.queue = {}
    self.__state.handle = nil
    self.__state.callbacks = {}
end

--- Send one or more messages to the remote machine, invoking the provided callback with the
--- response once it is received.
---
--- * `unaltered` when true, the callback will not be wrapped in the situation
---   where there is a single request payload entry to then return a single
---   response payload entry
--- * `multi` when true, the callback may be triggered multiple times and will
---   not be cleared within the Transport upon receiving an event. Instead, a
---   function is returned that will be called when we want to stop receiving
---   events whose origin is this message
---
--- @param msgs DistantApiMsg|DistantApiMsg[]
--- @param opts? {multi?:boolean, unaltered?:boolean}
--- @param cb fun(data:table, stop:fun()|nil)
--- @overload fun(msgs:DistantApiMsg|DistantApiMsg[], cb:fun(data:table, stop:fun()|nil))
function M:send(msgs, opts, cb)
    if type(cb) ~= 'function' then
        cb = opts
        opts = {}
    end

    if not opts then
        opts = {}
    end

    log.fmt_trace('Transport:send(%s, %s, _)', msgs, opts)
    assert(self:is_running(), 'distant api transport is not running!')

    local payload = msgs
    if not vim.tbl_islist(payload) then
        payload = { payload }
    end

    -- Build a full message that wraps the provided message as the payload and
    -- includes an id that our repl uses when relaying a response for the
    -- callback to process
    local full_msg = {
        id = tostring(utils.next_id()),
        payload = payload,
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
            -- NOTE: In the case of multi-responses, we might get back
            --       additional entries that are only one thing instead
            --       of a list (e.g. proc spawn stdout/stderr/done would
            --       still come back as one entry)
            --
            --       Because of that, we need to check if entries[1] would
            --       yield nil, and if so we just return entries itself
            entries = entries[1] or entries
            cb(entries, stop)
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

    -- If authenticated, we go ahead and send our message, otherwise we queue it
    -- to be sent as soon as we become authenticated
    if self.__state.authenticated then
        self.__state.handle.write(json)
    else
        table.insert(self.__state.queue, json)
    end
end

--- Send one or more messages to the remote machine and wait synchronously for the result
--- up to `timeout` milliseconds, checking every `interval` milliseconds for
--- a result (default timeout = 1000, interval = 200)
--
--- @param msgs DistantApiMsg|DistantApiMsg[]
--- @param opts? table
--- @return table
function M:send_wait(msgs, opts)
    opts = opts or {}
    log.fmt_trace('Transport:send_wait(%s, %s)', msgs, opts)
    local tx, rx = utils.oneshot_channel(
        opts.timeout or self.config.timeout,
        opts.interval or self.config.interval
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
--- @param msgs DistantApiMsg|DistantApiMsg[]
--- @param opts? table
--- @return table|nil
function M:send_wait_ok(msgs, opts)
    opts = opts or {}
    log.fmt_trace('Transport:send_wait_ok(%s, %s)', msgs, opts)
    local timeout = opts.timeout or self.config.timeout
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
function M:__handler(msg)
    assert(type(msg) == 'table', 'msg must be a table')
    log.fmt_trace('Transport:__handler(%s)', msg)

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

return M
