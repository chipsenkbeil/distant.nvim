local AuthHandler      = require('distant-core.auth.handler')
local builder          = require('distant-core.builder')
local Error            = require('distant-core.api.error')
local log              = require('distant-core.log')
local utils            = require('distant-core.utils')

local DEFAULT_TIMEOUT  = 15000
local DEFAULT_INTERVAL = 100

--- Represents a JSON-formatted distant.core.api transport.
--- @class distant.core.api.Transport
--- @field private auth_handler distant.core.auth.Handler
--- @field config {autostart:boolean, binary:string, network:distant.core.client.Network, timeout:number, interval:number}
--- @field private __state distant.core.api.transport.State
local M                = {}
M.__index              = M

--- @class distant.core.api.transport.State
--- @field authenticated boolean True if authenticated and ready to send messages
--- @field queue string[] Queue of outgoing json messages
--- @field handle? distant.core.utils.JobHandle
--- @field callbacks table<string, {callback:distant.core.api.transport.Callback, more:distant.core.api.transport.More}>

--- @alias distant.core.api.transport.Callback fun(payload:distant.core.api.msg.Payload)
--- @alias distant.core.api.transport.More fun(payload:distant.core.api.msg.Payload):boolean

--- @class distant.core.api.Msg
--- @field id string # unique id of the message
--- @field origin_id? string # if a response, will be set to the id of the request
--- @field payload distant.core.api.msg.Payload # a singular payload or multiple payloads

--- @alias distant.core.api.msg.Payload table|table[]

--- @class distant.core.api.transport.NewOpts
--- @field binary string
--- @field network? distant.core.client.Network
--- @field auth_handler? distant.core.auth.Handler
--- @field autostart? boolean
--- @field timeout? number
--- @field interval? number

--- Creates a new instance of our api that wraps a job.
--- @param opts distant.core.api.transport.NewOpts
--- @return distant.core.api.Transport
function M:new(opts)
    opts = opts or {}

    local instance = {}
    setmetatable(instance, M)
    instance.config = {
        autostart = opts.autostart or false,
        binary = assert(opts.binary, 'Transport missing binary'),
        network = vim.deepcopy(opts.network) or {},
        timeout = opts.timeout or DEFAULT_TIMEOUT,
        interval = opts.interval or DEFAULT_INTERVAL,
    }

    instance.auth_handler = opts.auth_handler or AuthHandler:new()

    instance.__state = {
        authenticated = false,
        queue = {},
        handle = nil,
        callbacks = {},
    }

    return instance
end

--- Whether or not the api is running
--- @return boolean
function M:is_running()
    return self.__state.handle ~= nil and self.__state.handle:running()
end

--- Starts the api if it is not already running. Will do nothing if running.
--- @param cb? fun(code:number) Optional callback when the api exits
function M:start(cb)
    -- Do nothing if already running
    if self:is_running() then
        return
    end

    local auth = self.auth_handler

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
                --- @type boolean,distant.core.api.Msg|distant.core.auth.Request|nil
                local success, msg = pcall(vim.fn.json_decode, line)

                -- Quit if the decoding failed or we didn't get a msg
                if not success or not msg then
                    log.fmt_error('Failed to decode to json: "%s"', line)
                    return
                end

                if auth:is_auth_request(msg) then
                    --- @cast msg distant.core.auth.Request
                    self:__handle_auth_request(msg)
                else
                    if type(msg) ~= 'table' then
                        log.fmt_error('type(msg) == \'%s\' (needed table): %s', type(msg), msg)
                        return
                    elseif type(msg.id) ~= 'string' then
                        log.fmt_error('type(msg.id) == \'%s\' (needed string): %s', type(msg.id), msg)
                        return
                    elseif msg.origin_id ~= nil and type(msg.origin_id) ~= 'string' then
                        log.fmt_error('type(msg.origin_id) == \'%s\' (needed string): %s', type(msg.origin_id), msg)
                        return
                    elseif type(msg.payload) ~= 'table' then
                        log.fmt_error('type(msg.payload) == \'%s\' (needed table): %s', type(msg.payload), msg)
                        return
                    end

                    --- @cast msg distant.core.api.Msg
                    self:__handle_response(msg)
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

--- @class distant.core.api.transport.SendOpts
--- @field payload table
--- @field verify? fun(payload:table):boolean #if provided, will be invoked to verify the response payload is valid
--- @field map? fun(payload:table):any #if provided, will transform the response payload before returning it
--- @field more? fun(payload:table):boolean
--- @field timeout? number
--- @field interval? number

--- Send payload to the remote machine, invoking the provided callback with the
--- response once it is received. If `more` is provided, the response payload
--- is passed to the function, which will return true if more responses to the
--- same originating payload are expected.
---
--- Invokes the provided callback with the response payload once received. If
--- `more` is used, this callback may be invoked more than once.
---
--- @param opts distant.core.api.transport.SendOpts
--- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.msg.Payload)
--- @return distant.core.api.Error|nil, distant.core.api.msg.Payload|nil
function M:send(opts, cb)
    local verify = function(payload)
        local success, value = pcall(opts.verify, payload)
        return success == true and value == true
    end
    local payload = opts.payload

    -- Asynchronous if cb provided, otherwise synchronous
    if type(cb) == 'function' then
        self:send_async({ payload = payload }, function(res)
            if type(res) == 'table' and res.type == 'error' then
                if type(res.kind) ~= 'string' or type(res.description) ~= 'string' then
                    cb(Error:new({
                        kind = Error.kinds.invalid_data,
                        description = 'Malformed error received: ' .. vim.inspect(res),
                    }), nil)
                else
                    cb(Error:new(res), nil)
                end

                return
            end

            if not type(res) == 'table' then
                cb(Error:new({
                    kind = Error.kinds.invalid_data,
                    description = 'Invalid response payload: ' .. vim.inspect(res),
                }), nil)
                return
            elseif type(verify) == 'function' and type(res) == 'table' and not verify(res) then
                cb(Error:new({
                    kind = Error.kinds.invalid_data,
                    description = 'Invalid response payload: ' .. vim.inspect(res),
                }), nil)
                return
            end

            if type(opts.map) == 'function' and type(res) == 'table' then
                res = opts.map(res)
            end

            cb(nil, res)
        end)
    else
        local err, res = self:send_sync({
            payload = payload,
            timeout = opts.timeout,
            interval = opts.interval
        })

        if err then
            return err
        end

        if type(res) == 'table' and res.type == 'error' then
            if type(res.kind) ~= 'string' or type(res.description) ~= 'string' then
                return Error:new({
                    kind = Error.kinds.invalid_data,
                    description = 'Malformed error received: ' .. vim.inspect(res),
                })
            else
                return Error:new(res), nil
            end
        end

        if not type(res) == 'table' then
            return Error:new({
                kind = Error.kinds.invalid_data,
                description = 'Invalid response payload: ' .. vim.inspect(res),
            })
        elseif type(verify) == 'function' and type(res) == 'table' and not verify(res) then
            return Error:new({
                kind = Error.kinds.invalid_data,
                description = 'Invalid response payload: ' .. vim.inspect(res),
            })
        end

        if type(opts.map) == 'function' and type(res) == 'table' then
            res = opts.map(res)
        end

        return nil, res
    end
end

--- Send payload to the remote machine, invoking the provided callback with the
--- response once it is received. If `more` is provided, the response payload
--- is passed to the function, which will return true if more responses to the
--- same originating payload are expected.
---
--- Invokes the provided callback with the response payload once received. If
--- `more` is used, this callback may be invoked more than once.
---
--- @param opts {payload:distant.core.api.msg.Payload, more?:distant.core.api.transport.More}
--- @param cb distant.core.api.transport.Callback
function M:send_async(opts, cb)
    log.fmt_trace('Transport:send_async(%s, _)', opts)
    if not self:is_running() then
        if self.config.autostart == true then
            log.debug('Transport not running and autostart enabled, so attempting to start')
            self:start(function(code)
                -- Ignore code 143, which is neovim terminating, as this will get
                -- printed when neovim exits
                if code ~= 0 and code ~= 143 then
                    log.fmt_debug('API process exited: %s', code)
                end
            end)
        else
            log.warn('Transport not running and autostart disabled, so reporting error')
            cb({
                type = 'error',
                kind = Error.kinds.not_connected,
                description = 'Transport not started',
            })
            return
        end
    end

    -- Build a full message that wraps the provided message as the payload and
    -- includes an id that our api uses when relaying a response for the
    -- callback to process
    local full_msg = {
        id = tostring(utils.next_id()),
        payload = opts.payload,
    }

    self.__state.callbacks[full_msg.id] = {
        callback = cb,
        more = opts.more or function() return false end,
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
--- a result (default timeout = 1000, interval = 200). Returns an error if timeout exceeded.
--
--- @param opts {payload:distant.core.api.msg.Payload, more?:distant.core.api.transport.More, timeout?:number, interval?:number}
--- @return distant.core.api.Error|nil, distant.core.api.msg.Payload|nil
function M:send_sync(opts)
    log.fmt_trace('Transport:send_sync(%s)', opts)
    local tx, rx = utils.oneshot_channel(
        opts.timeout or self.config.timeout,
        opts.interval or self.config.interval
    )

    self:send_async(opts, tx)

    --- @type boolean, string|distant.core.api.msg.Payload
    local success, results = pcall(rx)
    if not success then
        --- @cast results string
        return Error:new({ kind = Error.kinds.timed_out, description = results })
    else
        --- @cast results distant.core.api.msg.Payload
        return nil, results
    end
end

--- Authentication event handler, processing authentication requests.
--- @private
--- @param msg distant.core.auth.Request
function M:__handle_auth_request(msg)
    local auth = self.auth_handler

    -- The function passed is used to reply, and is NOT handled asynchronously.
    -- It is a blocking function, so we can be sure that our state is updated
    -- and any response is written prior to lines occurring later like checking
    -- the finished status of authentication.
    --
    --- @diagnostic disable-next-line:redefined-local
    auth:handle_request(msg, function(msg)
        local handle = self.__state.handle
        if handle then
            handle.write(utils.compress(vim.fn.json_encode(msg)) .. '\n')
        else
            log.fmt_warn('Job handle dropped, so unable to write %s', msg)
        end
    end)

    -- The above function is
    self.__state.authenticated = auth.finished

    -- We have finished authentication, so write out
    -- all of our queued messages
    if auth.finished then
        for _, json in ipairs(self.__state.queue) do
            self.__state.handle.write(json)
        end
        self.__state.queue = {}
    end
end

--- Primary event handler, routing responses to the corresponding callbacks.
--- @private
--- @param msg {id:string, origin_id:string, payload:distant.core.api.msg.Payload}
function M:__handle_response(msg)
    log.fmt_trace('Transport:__handler(%s)', msg)
    local origin_id = msg.origin_id
    local payload = msg.payload

    -- If no payload, nothing to process for a callback
    if not payload then
        return
    end

    --- @generic T
    --- @param payload T
    --- @return T
    local function clean_payload(payload)
        if type(payload) == 'table' then
            if vim.tbl_islist(payload) then
                return vim.tbl_map(clean_payload, payload)
            else
                for key, value in pairs(payload) do
                    if value == vim.NIL then
                        payload[key] = nil
                    else
                        payload[key] = clean_payload(value)
                    end
                end
                return payload
            end
        else
            return payload
        end
    end

    -- Clean payload by converting vim.NIL values to nil
    payload = clean_payload(payload)

    -- Look up our callback and, if it exists, invoke it
    if origin_id ~= nil and origin_id ~= vim.NIL then
        local cb_state = self.__state.callbacks[origin_id]
        if cb_state ~= nil then
            log.fmt_trace('Transport has found callback for %s', origin_id)
            local cb = cb_state.callback
            local more = cb_state.more

            if not more(payload) then
                log.fmt_trace('Transport will stop receiving msgs for %s', origin_id)
                self.__state.callbacks[origin_id] = nil
            end

            log.fmt_trace('Transport triggering callback for %s', origin_id)
            cb(payload)
            return
        else
            log.fmt_warn('Discarding message with origin %s as no callback exists', origin_id)
        end
    end
end

return M