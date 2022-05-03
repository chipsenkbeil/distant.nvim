local log = require('distant.log')
local state = require('distant.state')
local utils = require('distant.utils')

local api = require('distant.client.api')
local install = require('distant.client.install')
local lsp = require('distant.client.lsp')
local term = require('distant.client.term')
local errors = require('distant.client.errors')

--- Represents a Client connected to a remote machine
--- @class Client
--- @field id string #Represents an arbitrary unique id for the client
--- @field api ClientApi #General API to perform operations remotely
--- @field lsp ClientLsp #LSP API to spawn a process that behaves like an LSP server
--- @field term ClientTerm #Terminal API to spawn a process that behaves like a terminal
--- @field __state InternalState
--- @field __settings InternalSettings
local Client = {}
Client.__index = Client

--- @class InternalState
--- @field tenant? string
--- @field handle? JobHandle
--- @field callbacks table<string, InternalCallback>
--- @field session? Session

--- @class InternalSettings
--- @field bin string
--- @field timeout number
--- @field interval number

--- @class InternalCallback
--- @field callback fun(payload:table) @Invoked with payload from received event
--- @field multi boolean @If true, will not clear the callback after first invocation
--- @field stop fun() @When called, will stop the callback from being invoked and clear it

--- @class Session
--- @field host string
--- @field port number
--- @field key string

--- @class ClientNewOpts
--- @field bin? string
--- @field timeout? number
--- @field interval? number

--- Creates a new instance of our client that is not yet connected
--- @param opts? ClientNewOpts Options for use with our client
--- @return Client
function Client:new(opts)
    local instance = {}
    setmetatable(instance, Client)
    instance.id = 'client_' .. tostring(utils.next_id())
    instance.api = api(instance)
    instance.lsp = lsp(instance)
    instance.term = term(instance)

    instance.__state = {
        tenant = nil;
        handle = nil;
        callbacks = {};
        session = nil;
    }

    opts = opts or {}
    instance.__settings = {
        bin = opts.bin or state.settings.client.bin;
        timeout = opts.timeout or state.settings.max_timeout;
        interval = opts.interval or state.settings.timeout_interval;
    }
    return instance
end

--- @class ClientInstallOpts
--- @field bin? string
--- @field timeout? number
--- @field interval? number
--- @field check_version? fun(version:ClientVersion):boolean

--- Creates a client, checks if the binary is available on path, and
--- installs the binary if it is not. Will also check the version and
--- attempt to install the binary if the available version fails
--- our check
--- @param opts? ClientInstallOpts
--- @param cb fun(err:string|boolean, client:Client|nil)
function Client:install(opts, cb)
    if not cb then
        cb = opts
        opts = {}
    end

    local client = Client:new(opts)
    local has_bin = vim.fn.executable(client.__settings.bin) == 1
    local check_version = opts.check_version

    local function validate_client()
        local ok = true
        if check_version then
            local version = client:version()
            if not version then
                return cb('Unable to detect binary version')
            end
            ok = check_version(version)
        end


        if ok then
            vim.schedule(function() cb(false, client) end)
        end

        return ok
    end

    if has_bin and validate_client() then
        return
    end

    return install.install(function(success, result)
        if not success then
            return cb(result)
        else
            -- Ensure that our client's internal binary has been set
            client.__settings.bin = result
            validate_client()
        end
    end)
end

--- Whether or not the client is connected to a remote server
--- @return boolean
function Client:is_connected()
    return not (not self.__state.session)
end

--- Represents the tenant name used by the client when communicating with the server
--- @return string|nil
function Client:tenant()
    return self.__state.tenant
end

--- Returns the binary used by the client
--- @return string path to the binary
function Client:binary()
    return self.__settings.bin
end

--- Returns the maximum timeout in milliseconds for a request
--- @return number timeout for a request in milliseconds
function Client:max_timeout()
    return self.__settings.timeout
end

--- Returns the time in milliseconds to wait between checking for a request to complete
--- @return number interval for a timeout for a request in milliseconds
function Client:timeout_interval()
    return self.__settings.interval
end

--- Returns the active session of the client, if it has one
--- @return Session|nil
function Client:session()
    return self.__state.session
end

--- @class ClientVersion
--- @field major number
--- @field minor number
--- @field patch number
--- @field pre_release string|nil
--- @field pre_release_version number

--- Retrieves the current version of the binary, returning it  or nil if not available
--- @return ClientVersion|nil
function Client:version()
    local raw_version = vim.fn.system(self.__settings.bin .. ' --version')
    if not raw_version then
        return nil
    end

    local version_string = vim.trim(utils.strip_prefix(
        vim.trim(raw_version),
        self.__settings.bin
    ))
    if not version_string then
        return nil
    end

    local semver, ext = unpack(vim.split(version_string, '-', true))
    local major, minor, patch = unpack(vim.split(semver, '.', true))

    local pre_release, pre_release_version
    if ext then
        pre_release, pre_release_version = unpack(vim.split(ext, '.', true))
    end

    local version = {
        major = major,
        minor = minor,
        patch = patch,
        pre_release = pre_release,
        pre_release_version = pre_release_version,
    }

    return utils.filter_map(version, (function(v)
        return tonumber(v) or v
    end))
end

--- @class LaunchOpts
--- @field host string
--- @field port? number
--- @field on_exit? fun(exit_code:number)
--- @field connect? boolean | fun(exit_code:number) #If true, will connect after launching; if function, will be invoked when connection exits

--- Launches a server remotely and performs authentication with the remote server
---
--- @param opts LaunchOpts
--- @param cb fun(err?:string, session?:Session)
function Client:launch(opts, cb)
    log.fmt_debug('Authenticating with options: %s', opts)
    opts = opts or {}
    vim.validate({
        host={opts.host, 'string'},
        port={opts.port, 'number', true},
        on_exit={opts.on_exit, 'function', true},
    })

    if vim.fn.executable(self.__settings.bin) ~= 1 then
        log.fmt_error('Executable %s is not on path', self.__settings.bin)
        return
    end

    --- @param ev table
    --- @param handle JobHandle
    --- @return boolean @true if okay, otherwise false
    local on_event = function(ev, handle)
        local type = ev.type
        local msg = {}

        if type == 'ssh_authenticate' then
            if ev.username then
                print('Authentication for ' .. ev.username)
            end
            if ev.instructions then
                print(ev.instructions)
            end

            local answers = {}
            for _, p in ipairs(ev.prompts) do
                if p.echo then
                    table.insert(answers, vim.fn.input(p.prompt))
                else
                    table.insert(answers, vim.fn.inputsecret(p.prompt))
                end
            end

            msg = {
                type = 'ssh_authenticate_answer',
                answers = answers
            }
        elseif type == 'ssh_banner' then
            print(ev.text)
            return true
        elseif type == 'ssh_host_verify' then
            local answer = vim.fn.input(string.format('%s\nEnter [y/N]> ', ev.host))
            msg = {
                type = 'ssh_host_verify_answer',
                answer = answer == 'y' or answer == 'Y' or answer == 'yes' or answer == 'YES'
            }
        elseif type == 'ssh_error' then
            log.fmt_error('Authentication error: %s', ev)
            return false
        else
            log.fmt_error('Unknown authentication event received: %s', ev.msg)
            return false
        end

        local json = utils.compress(vim.fn.json_encode(msg)) .. '\n'
        handle.write(json)
        return true
    end

    local args = utils.build_arg_str(utils.merge(opts, {
        interactive = true;
        format = 'json';
        session = 'pipe';
        port = tostring(opts.port);
    }), {'host', 'port', 'on_exit'})

    local cmd = vim.trim(self.__settings.bin .. ' launch ' .. args .. ' ' .. opts.host)
    log.fmt_debug('Launch cmd: %s', cmd)

    local handle
    handle = utils.job_start(cmd, {
        on_success = function()
            if type(opts.on_exit) == 'function' then
                opts.on_exit(0)
            end
        end;
        on_failure = function(code)
            log.fmt_error(
                'Launch failed (%s): %s',
                tostring(code),
                errors.description_by_code(code) or '???'
            )

            if type(opts.on_exit) == 'function' then
                opts.on_exit(code)
            end
        end;
        on_stdout_line = function(line)
            if line ~= nil and line ~= "" then
                if vim.startswith(line, 'DISTANT CONNECT') then
                    local s = vim.trim(utils.strip_prefix(line, 'DISTANT CONNECT'))
                    local tokens = vim.split(s, ' ', {plain = true, trimempty = true})
                    local session = {
                        host = vim.trim(tokens[1]),
                        port = tonumber(tokens[2]),
                        key = vim.trim(tokens[3]),
                    }

                    -- If we want to connect after launching, do so
                    if type(opts.connect) == 'boolean' and opts.connect then
                        self:connect({session = session})
                    elseif type(opts.connect) == 'function' then
                        self:connect({session = session, on_exit = opts.connect})
                    end

                    cb(false, session)
                else
                    on_event(vim.fn.json_decode(line), handle)
                end
            end
        end;
        on_stderr_line = function(line)
            if line ~= nil and line ~= "" then
                log.error(line)
            end
        end
    })
end

--- @class ConnectOpts
--- @field on_exit? fun(exit_code:number)
--- @field session Session

--- Connects this client to a remote server
--- @param opts ConnectOpts
function Client:connect(opts)
    log.fmt_debug('Starting client with options: %s', opts)
    assert(not self:is_connected(), 'Client is already connected!')
    opts = opts or {}

    vim.validate({
        on_exit={opts.on_exit, 'function', true},
        session={opts.session, 'table'}
    })
    vim.validate({
        host={opts.session.host, 'string'},
        port={opts.session.port, 'number'},
        key={opts.session.key, 'string'},
    })

    if vim.fn.executable(self.__settings.bin) ~= 1 then
        log.fmt_error('Executable %s is not on path', self.__settings.bin)
        return
    end

    local args = utils.build_arg_str(utils.merge(opts, {
        interactive = true;
        format = 'json';
        session = 'pipe';
    }), {'on_exit', 'session'})

    local cmd = vim.trim(self.__settings.bin .. ' action ' .. args)
    log.fmt_debug('Client cmd: %s', cmd)
    local handle = utils.job_start(cmd, {
        on_success = function()
            if type(opts.on_exit) == 'function' then
                opts.on_exit(0)
            end
            self:stop()
        end;
        on_failure = function(code)
            log.fmt_error(
                'Connect failed (%s): %s',
                tostring(code),
                errors.description_by_code(code) or '???'
            )

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
    handle.write(
        'DISTANT CONNECT '
        .. opts.session.host
        .. ' '
        .. tostring(opts.session.port)
        .. ' '
        .. opts.session.key
        .. '\n'
    )

    self.__state = {
        tenant = 'nvim_tenant_' .. utils.next_id();
        handle = handle;
        callbacks = {};
    }
end

--- Stops an instance of distant if running by killing the process
--- and resetting state
function Client:stop()
    if self.__state.handle ~= nil then
        self.__state.handle.stop()
    end
    self.__state.tenant = nil
    self.__state.handle = nil
    self.__state.callbacks = {}
    self.__state.session = nil
end

--- @class ClientMsg
--- @field type string
--- @field data table

--- @alias OneOrMoreMsgs ClientMsg|ClientMsg[]

--- @class SendOpts
--- @field unaltered? boolean @when true, the callback will not be wrapped in the situation where there is
---                           a single request payload entry to then return a single response payload entry
--- @field multi? boolean @when true, the callback may be triggered multiple times and will not be cleared
---                       within the Client upon receiving an event. Instead, a function is returned that will
---                       be called when we want to stop receiving events whose origin is this message

--- Send one or more messages to the remote machine, invoking the provided callback with the
--- response once it is received
---
--- @param msgs OneOrMoreMsgs
--- @param opts? SendOpts
--- @param cb fun(data:table, stop:fun()|nil)
function Client:send(msgs, opts, cb)
    if type(cb) ~= 'function' then
        cb = opts
        opts = {}
    end

    opts = opts or {}
    log.fmt_trace('Client:send(%s, %s, _)', msgs, opts)
    assert(self:is_connected(), 'Client is not connected!')

    local payload = msgs
    if not vim.tbl_islist(payload) then
        payload = {payload}
    end

    -- Build a full message that wraps the provided message as the payload and
    -- includes an id that our client uses when relaying a response for the
    -- callback to process
    local full_msg = {
        tenant = self.__state.tenant;
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
function Client:send_wait(msgs, opts)
    opts = opts or {}
    log.fmt_trace('Client:send_wait(%s, %s)', msgs, opts)
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
function Client:send_wait_ok(msgs, opts)
    opts = opts or {}
    log.fmt_trace('Client:send_wait_ok(%s, %s)', msgs, opts)
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
function Client:__handler(msg)
    assert(type(msg) == 'table', 'msg must be a table')
    log.fmt_trace('Client:__handler(%s)', msg)

    -- {"id": ..., "origin_id": ..., "payload": ...}
    local origin_id = msg.origin_id
    local payload = msg.payload

    -- If no payload, nothing to process for a callback
    if not payload then
        return
    end

    --- @type fun(payload:table)|nil
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
            if not cb_state.multi then
                self.__state.callbacks[origin_id] = nil
            end
        end
    end

    if cb then
        return cb(payload, stop)
    else
        log.fmt_warn('Discarding message with origin %s as no callback exists', origin_id)
    end
end

return Client
