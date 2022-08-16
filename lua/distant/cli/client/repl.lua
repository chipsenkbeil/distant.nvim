local log   = require('distant.log')
local utils = require('distant.utils')

local Cmd = require('distant.cli.cmd')

local DEFAULT_TIMEOUT = 15000
local DEFAULT_INTERVAL = 100

--- Represents a JSON-formatted distant client REPL
--- @class ClientRepl
--- @field config ClientReplConfig
--- @field __state ClientReplState
local ClientRepl = {}
ClientRepl.__index = ClientRepl

--- @class ClientReplConfig
--- @field binary string
--- @field network ClientNetwork
--- @field timeout number|nil
--- @field interval number|nil

--- @class ClientReplState
--- @field handle? JobHandle
--- @field callbacks table<string, ClientReplCallback>

--- @class ClientReplCallback
--- @field callback fun(payload:table) #Invoked with payload from received event
--- @field multi boolean #If true, will not clear the callback after first invocation
--- @field stop fun() #When called, will stop the callback from being invoked and clear it

--- @class ClientReplMsg
--- @field type string
--- @field data table

--- @alias OneOrMoreMsgs ClientReplMsg|ClientReplMsg[]

--- @class SendOpts
--- @field unaltered? boolean #when true, the callback will not be wrapped in the situation where there is
---                           a single request payload entry to then return a single response payload entry
--- @field multi? boolean #when true, the callback may be triggered multiple times and will not be cleared
---                       within the Repl upon receiving an event. Instead, a function is returned that will
---                       be called when we want to stop receiving events whose origin is this message

--- Creates a new instance of our repl that wraps a job
--- @param opts ClientReplConfig
--- @return ClientRepl
function ClientRepl:new(opts)
    opts = opts or {}

    local instance = {}
    setmetatable(instance, ClientRepl)
    instance.config = opts
    instance.config.timeout = instance.config.timeout or DEFAULT_TIMEOUT
    instance.config.interval = instance.config.interval or DEFAULT_INTERVAL

    instance.__state = {
        handle = nil;
        callbacks = {};
    }

    return instance
end

--- Whether or not the repl is running
--- @return boolean
function ClientRepl:is_running()
    return self.__state.handle ~= nil and self.__state.handle:running()
end

--- Starts the repl if it is not already running
--- @param cb fun(code:number)|nil #optional callback when the repl exits
function ClientRepl:start(cb)
    if not self:is_running() then
        local cmd = Cmd.client.repl():set_from_tbl(self.config.network):as_list()
        table.insert(cmd, 0, self.config.binary)

        local handle
        handle = utils.job_start(cmd, {
            on_success = function()
                self:stop()
                if cb ~= nil then
                    cb(0)
                end
            end;
            on_failure = function(code)
                self:stop()
                if cb ~= nil then
                    cb(code)
                end
            end;
            on_stdout_line = function(line)
                if line ~= nil and line ~= "" then
                    self:__handler(vim.fn.json_decode(line))
                end
            end;
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
function ClientRepl:stop()
    if self.__state.handle ~= nil and self.__state.handle:running() then
        self.__state.handle.stop()
    end
    self.__state.handle = nil
    self.__state.callbacks = {}
end

--- Send one or more messages to the remote machine, invoking the provided callback with the
--- response once it is received
---
--- @param msgs OneOrMoreMsgs
--- @param opts? SendOpts
--- @param cb fun(data:table, stop:fun()|nil)
function ClientRepl:send(msgs, opts, cb)
    if type(cb) ~= 'function' then
        cb = opts
        opts = {}
    end

    if not opts then
        opts = {}
    end

    log.fmt_trace('ClientRepl:send(%s, %s, _)', msgs, opts)
    assert(self:is_running(), 'ClientRepl is not running!')

    local payload = msgs
    if not vim.tbl_islist(payload) then
        payload = { payload }
    end

    -- Build a full message that wraps the provided message as the payload and
    -- includes an id that our repl uses when relaying a response for the
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
function ClientRepl:send_wait(msgs, opts)
    opts = opts or {}
    log.fmt_trace('ClientRepl:send_wait(%s, %s)', msgs, opts)
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
--- @param msgs OneOrMoreMsgs
--- @param opts? table
--- @return table|nil
function ClientRepl:send_wait_ok(msgs, opts)
    opts = opts or {}
    log.fmt_trace('ClientRepl:send_wait_ok(%s, %s)', msgs, opts)
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
function ClientRepl:__handler(msg)
    assert(type(msg) == 'table', 'msg must be a table')
    log.fmt_trace('ClientRepl:__handler(%s)', msg)

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

return ClientRepl
