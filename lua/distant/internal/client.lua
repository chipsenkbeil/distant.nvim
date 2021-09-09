local log = require('distant.log')
local s = require('distant.internal.state')
local u = require('distant.internal.utils')

--- Represents a client connected to a remote machine
local client = {}
client.__index = client

--- Creates a new instance of our client that is not yet connected
function client:new()
    local instance = {}
    setmetatable(instance, client)
    instance.__state = {
        tenant = nil;
        handle = nil;
        callbacks = {};
        registered = {};
    }
    return instance
end

--- Returns true if the client is actively running
function client:is_running()
    return not (not self.__state.handle)
end

--- Retrieves the current version of the binary, returning it in the form
--- of {major, minor, patch, pre-release, pre-release-ver} or nil if not available.
---
--- Note that pre-release and pre-release ver are optional
function client:version()
    local raw_version = vim.fn.system(s.settings.binary_name .. ' --version')
    if not raw_version then
        return nil
    end

    local version_string = vim.trim(u.strip_prefix(vim.trim(raw_version), s.settings.binary_name))
    if not version_string then
        return nil
    end

    local version = nil

    local semver, ext = unpack(vim.split(version_string, '-', true))
    local major, minor, patch = unpack(vim.split(semver, '.', true))
    if ext then
        local ext_label, ext_ver = unpack(vim.split(ext, '.', true))
        version = {major, minor, patch, ext_label, ext_ver}
    else
        version = {major, minor, patch}
    end

    return u.filter_map(version, (function(v)
        return tonumber(v) or v
    end))
end

--- Starts an instance of the client if not already running
---
--- Takes an optional set of options to define special handlers:
---
--- * on_exit: a function that is invoked when the client exits
--- * verbose: level of verbosity to apply to the client when spawned
function client:start(opts)
    log.fmt_debug('Starting client with options: %s', opts)
    assert(not self:is_running(), 'client is already running!')
    opts = opts or {}

    if vim.fn.executable(s.settings.binary_name) ~= 1 then
        log.fmt_error('Executable %s is not on path', s.settings.binary_name)
        return
    end

    local session = s.session()
    local args = u.build_arg_str(u.merge(opts, {
        interactive = true;
        format = 'json';
        session = 'pipe';
    }), {'on_exit', 'verbose'})
    if type(opts.verbose) == 'number' and opts.verbose > 0 then
        args = vim.trim(args .. ' -' .. string.rep('v', opts.verbose))
    end

    local cmd = vim.trim(s.settings.binary_name .. ' action ' .. args)
    log.fmt_debug('Client cmd: %s', cmd)
    local handle = u.job_start(cmd, {
        on_success = function()
            if type(opts.on_exit) == 'function' then
                opts.on_exit(0)
            end
            self:stop()
        end;
        on_failure = function(code)
            if type(opts.on_exit) == 'function' then
                opts.on_exit(code)
            end
            self:stop()
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

    -- Send our session initialization line
    if session ~= nil then
        log.trace('Sending session initialization line')
        handle.write(
            'DISTANT DATA '
            .. session.host
            .. ' '
            .. session.port
            .. ' '
            .. session.auth_key
            .. '\n'
        )
    end

    self.__state = {
        tenant = 'nvim_tenant_' .. u.next_id();
        handle = handle;
        callbacks = {};
        registered = self.__state.registered;
    }
end

--- Stops an instance of distant if running by killing the process
--- and resetting state
function client:stop()
    if self.__state.handle ~= nil then
        self.__state.handle.stop()
    end
    self.__state.tenant = nil
    self.__state.handle = nil
    self.__state.callbacks = {}
end

--- Send one or more messages to the remote machine, invoking the provided callback with the
--- response once it is received
---
--- Supports the following options:
---
--- * unaltered: when true, the callback will not be wrapped in the situation where there is
---   a single request payload entry to then return a single response payload entry
function client:send(msgs, cb, opts)
    opts = opts or {}
    log.fmt_trace('client:send(%s, _, %s)', msgs, opts)
    assert(self:is_running(), 'client is not running!')

    local payload = msgs
    if not vim.tbl_islist(payload) then
        payload = {payload}
    end

    -- Build a full message that wraps the provided message as the payload and
    -- includes an id that our client uses when relaying a response for the
    -- callback to process
    local full_msg = {
        tenant = self.__state.tenant;
        id = u.next_id();
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
        callback = function(entries)
            cb(entries[1])
        end
    end
    self.__state.callbacks[full_msg.id] = callback

    local json = u.compress(vim.fn.json_encode(full_msg)) .. '\n'
    self.__state.handle.write(json)
end

--- Send one or more messages to the remote machine and wait synchronously for the result
--- up to `timeout` milliseconds, checking every `interval` milliseconds for
--- a result (default timeout = 1000, interval = 200)
function client:send_wait(msgs, opts)
    opts = opts or {}
    log.fmt_trace('client:send_wait(%s, %s)', msgs, opts)
    local tx, rx = u.oneshot_channel(
        opts.timeout or s.settings.max_timeout,
        opts.interval or s.settings.timeout_interval
    )

    self:send(msgs, function(data)
        tx(data)
    end)

    return rx()
end

--- Send one or more messages to the remote machine, wait synchronously for the result up
--- to `timeout` milliseconds, checking every `interval` milliseconds for a
--- result (default timeout = 1000, interval = 200), and report an error if not okay
function client:send_wait_ok(msgs, opts)
    opts = opts or {}
    log.fmt_trace('client:send_wait_ok(%s, %s)', msgs, opts)
    local timeout = opts.timeout or s.settings.max_timeout
    local result = self:send_wait(msgs, opts)
    if result == nil then
        log.fmt_error('Max timeout (%s) reached waiting for result', timeout)
    elseif result.type == 'error' then
        log.fmt_error('Call failed: %s', vim.inspect(result.data.description))
    else
        return result
    end
end

--- Register a callback to be invoked when a message is received without an origin
---
--- Also takes a second argument that is a function that, when called, unregisters
--- the callback
---
--- Returns an id tied to the registered callback
function client:register_broadcast(cb)
    local id = u.next_id()
    self.__state.registered['cb_' .. id] = cb
    return id
end

--- Unregisters a broadcast callback with the specified id
function client:unregister_broadcast(id)
    self.__state.registered['cb_' .. id] = nil
end

--- Primary event handler, routing received events to the corresponding callbacks
function client:__handler(msg)
    assert(type(msg) == 'table', 'msg must be a table')
    log.fmt_trace('client:__handler(%s)', msg)

    -- {"id": ..., "origin_id": ..., "payload": ...}
    local origin_id = msg.origin_id
    local payload = msg.payload

    -- If no payload, nothing to process for a callback
    if not payload then
        return
    end

    -- Look up our callback and, if it exists, invoke it
    local cb = nil
    if origin_id ~= vim.NIL then
        cb = self.__state.callbacks[origin_id]
        self.__state.callbacks[origin_id] = nil
    end

    if cb then
        cb(payload)
    else
        -- Otherwise, we pass the payload to each registered broadcast function
        for id, r in pairs(self.__state.registered) do
            r(payload, function()
                self:unregister_broadcast(id)
            end)
        end
    end
end

return client
