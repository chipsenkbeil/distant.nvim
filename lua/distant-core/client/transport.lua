local AuthHandler      = require('distant-core.auth.handler')
local builder          = require('distant-core.builder')
local log              = require('distant-core.log')
local utils            = require('distant-core.utils')

local DEFAULT_TIMEOUT  = 15000
local DEFAULT_INTERVAL = 100

--- Represents a JSON-formatted distant api transport.
--- @class DistantApiTransport
--- @field private auth_handler AuthHandler
--- @field config {autostart:boolean, binary:string, network:DistantClientNetwork, timeout:number, interval:number}
--- @field private __state DistantApiTransportState
local M                = {}
M.__index              = M

--- @class DistantApiTransportState
--- @field authenticated boolean True if authenticated and ready to send messages
--- @field queue string[] Queue of outgoing json messages
--- @field handle? JobHandle
--- @field callbacks table<string, {callback:fun(payload:table), more:fun(payload:table):boolean}>

--- @alias DistantApiNewOpts {binary:string, network?:DistantClientNetwork, auth_handler?:AuthHandler, autostart?:boolean, timeout?:number, interval?:number}
--- Creates a new instance of our api that wraps a job.
--- @param opts DistantApiNewOpts
--- @return DistantApiTransport
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
                --- @type boolean,table|nil
                local success, msg = pcall(vim.fn.json_decode, line)

                -- Quit if the decoding failed or we didn't get a msg
                if not success then
                    log.fmt_error('Failed to decode to json: "%s"', line)
                    return
                end

                if type(msg) ~= 'table' or type(msg.type) ~= 'string' then
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

                    -- We have finished authentication, so write out
                    -- all of our queued messages
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

--- @class DistantApiTransportSendOpts
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
--- @param opts DistantApiTransportSendOpts
--- @param cb? fun(err?:string, payload?:table)
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
                if type(res.description) == 'string' then
                    local err = res.description

                    if type(res.kind) == 'string' then
                        err = '(' .. res.kind .. ') ' .. err
                    end

                    cb(err, nil)
                else
                    cb('Malformed error received: ' .. vim.inspect(res), nil)
                end

                return
            end

            if not type(res) == 'table' then
                cb('Invalid response payload: ' .. vim.inspect(res), nil)
                return
            elseif type(verify) == 'function' and type(res) == 'table' and not verify(res) then
                cb('Invalid response payload: ' .. vim.inspect(res), nil)
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
            if type(res.description) == 'string' then
                local res_err = res.description

                if type(res.kind) == 'string' then
                    res_err = '(' .. res.kind .. ') ' .. res_err
                end

                return res_err
            else
                return 'Malformed error received: ' .. vim.inspect(res)
            end
        end

        if not type(res) == 'table' then
            return 'Invalid response payload: ' .. vim.inspect(res)
        elseif type(verify) == 'function' and type(res) == 'table' and not verify(res) then
            return 'Invalid response payload: ' .. vim.inspect(res)
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
--- @param opts {payload:table, more?:fun(payload:table):boolean}
--- @param cb fun(payload:table)
function M:send_async(opts, cb)
    log.fmt_trace('Transport:send_async(%s, _)', opts)
    if not self:is_running() then
        if self.config.autostart == true then
            log.warn('Transport not running and autostart enabled, so attempting to start')
            self:start(function(code)
                log.fmt_debug('API process exited: %s', code)
            end)
        else
            log.warn('Transport not running and autostart disabled, so reporting error')
            cb({
                type = 'error',
                kind = 'not_connected',
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
--- a result (default timeout = 1000, interval = 200). Throws an error if timeout exceeded.
--
--- @param opts {payload:table, timeout?:number, interval?:number, more?:fun(payload:table):boolean}
--- @return string|nil, table|nil #Err?, Payload?
function M:send_sync(opts)
    log.fmt_trace('Transport:send_sync(%s)', opts)
    local tx, rx = utils.oneshot_channel(
        opts.timeout or self.config.timeout,
        opts.interval or self.config.interval
    )

    self:send_async(opts, tx)

    local err, payload = rx()
    return err, payload
end

--- Primary event handler, routing received events to the corresponding callbacks.
--- @param msg {id:string, origin_id:string, payload:table}
function M:__handler(msg)
    log.fmt_trace('Transport:__handler(%s)', msg)
    local origin_id = msg.origin_id
    local payload = msg.payload

    -- If no payload, nothing to process for a callback
    if not payload then
        return
    end

    -- Look up our callback and, if it exists, invoke it
    if origin_id ~= nil and origin_id ~= vim.NIL then
        local cb_state = self.__state.callbacks[origin_id]
        if cb_state ~= nil then
            local cb = cb_state.callback
            local more = cb_state.more

            if not more(payload) then
                self.__state.callbacks[origin_id] = nil
            end

            return cb(payload)
        else
            log.fmt_warn('Discarding message with origin %s as no callback exists', origin_id)
        end
    end
end

return M
