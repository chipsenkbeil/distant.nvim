local log = require('distant.log')
local state = require('distant.state')
local utils = require('distant.utils')

local Args = require('distant.client.args')
local api = require('distant.client.api')
local install = require('distant.client.install')
local lsp = require('distant.client.lsp')
-- local term = require('distant.client.term')
local errors = require('distant.client.errors')

--- Represents a Client connected to a remote machine
--- @class Client
--- @field id string #Represents an arbitrary unique id for the client
--- @field api ClientApi #General API to perform operations remotely
--- @field auth ClientAuth #Authentication-based handlers
--- @field lsp ClientLsp #LSP API to spawn a process that behaves like an LSP server
--- @field term ClientTerm #Terminal API to spawn a process that behaves like a terminal
--- @field __state InternalState
--- @field __settings InternalSettings
local Client = {}
Client.__index = Client

--- @class ClientAuth
--- @field on_authenticate? fun(msg:ClientAuthMsg):string[]
--- @field on_verify_host? fun(host:string):boolean
--- @field on_info? fun(text:string)
--- @field on_error? fun(err:string)
--- @field on_unknown? fun(x:any)

--- @class ClientAuthMsg
--- @field username? string
--- @field instructions? string
--- @field prompts {prompt:string, echo:boolean}[]

--- @return ClientAuth
local function make_client_auth()
    return {
        --- @param msg ClientAuthMsg
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

--- @alias LogLevel 'off'|'error'|'warn'|'info'|'debug'|'trace'

--- @class ClientNewOpts
--- @field auth? ClientAuth
--- @field bin? string
--- @field timeout? number
--- @field interval? number

--- Creates a new instance of our client that is not yet connected
--- @param opts? ClientNewOpts Options for use with our client
--- @return Client
function Client:new(opts)
    opts = opts or {}

    local instance = {}
    setmetatable(instance, Client)
    instance.id = 'client_' .. tostring(utils.next_id())
    instance.api = api(instance)
    instance.lsp = lsp(instance)
    -- instance.term = term(instance)

    instance.auth = vim.tbl_deep_extend(
        'keep',
        opts.auth or {},
        make_client_auth()
    )

    instance.__state = {
        tenant = nil;
        handle = nil;
        callbacks = {};
        session = nil;
    }

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
---
--- @field external_ssh? boolean
--- @field no_shell? boolean
--- @field distant? string
--- @field extra_server_args? string
--- @field identity_file? string
--- @field log_file? string
--- @field log_level? LogLevel
--- @field shutdown_after? number
--- @field ssh? string
--- @field username? string

--- Launches a server remotely and performs authentication with the remote server
---
--- @param opts LaunchOpts
--- @param cb fun(err?:string, session?:Session)
--- @return JobHandle|nil
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

    -- TODO: Support escaping single quotes in provided text
    local wrap_args = function(text)
        if vim.tbl_islist(text) then
            text = table.concat(text, ' ')
        else
            text = tostring(text)
        end

        local quote = '\''
        text = vim.trim(text)

        if not vim.startswith(text, quote) then
            text = quote .. text
        end

        if not vim.endswith(text, quote) then
            text = text .. quote
        end

        return text
    end

    local args = Args.launch(opts.host):set_from_tbl({
        format              = 'json';
        session             = 'pipe';

        -- Optional user settings
        external_ssh        = opts.external_ssh;
        no_shell            = opts.no_shell;
        distant             = opts.distant;
        extra_server_args   = wrap_args(opts.extra_server_args);
        identity_file       = opts.identity_file;
        log_file            = opts.log_file;
        log_level           = opts.log_level;
        port                = opts.port and tostring(opts.port);
        shutdown_after      = opts.shutdown_after;
        ssh                 = opts.ssh;
        username            = opts.username;
    }):as_string()

    local cmd = vim.trim(self.__settings.bin .. ' launch ' .. args)
    print('cmd ' .. cmd)
    log.fmt_debug('Launch cmd: %s', cmd)

    local handle, is_connected
    is_connected = false
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
                if vim.startswith(line, 'DISTANT CONNECT') and not is_connected then
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

                    -- NOTE: We have this flag for connection as for some reason the
                    --       DISTANT CONNECT line shows up twice
                    is_connected = true

                    cb(false, session)
                elseif not is_connected then
                    self:__auth_handler(
                        vim.fn.json_decode(line),
                        function(msg)
                            handle.write(utils.compress(vim.fn.json_encode(msg)) .. '\n')
                        end
                    )
                else
                    log.fmt_error('Unexpected msg: %s', line)
                end
            end
        end;
        on_stderr_line = function(line)
            if line ~= nil and line ~= "" then
                log.error(line)
            end
        end
    })

    return handle
end

--- @class ConnectOpts
--- @field on_exit? fun(exit_code:number)
--- @field method? 'distant'|'ssh'
--- @field session Session
--- @field ssh? ConnectSshOpts
--- @field log_file? string
--- @field log_level? LogLevel

--- @class ConnectSshOpts
--- @field host? string
--- @field port? number
--- @field user? string

--- Connects this client to a remote server
--- @param opts ConnectOpts
function Client:connect(opts)
    log.fmt_debug('Starting client with options: %s', opts)
    assert(not self:is_connected(), 'Client is already connected!')
    opts = opts or {}

    vim.validate({
        on_exit={opts.on_exit, 'function', true},
        session={opts.session, 'table'},
        method={opts.method, 'string', true},
        ssh={opts.ssh, 'table', true},
        log_file={opts.log_file, 'string', true},
        log_level={opts.log_level, 'string', true},
    })
    vim.validate({
        host={opts.session.host, 'string'},
        port={opts.session.port, 'number'},
        key={opts.session.key, 'string'},
    })
    if opts.ssh then
        vim.validate({
            host={opts.ssh.host, 'string', true},
            port={opts.ssh.port, 'number', true},
            user={opts.ssh.user, 'string', true},
        })
    end

    if vim.fn.executable(self.__settings.bin) ~= 1 then
        log.fmt_error('Executable %s is not on path', self.__settings.bin)
        return
    end

    --- @type 'distant'|'ssh'
    local method = opts.method or 'distant'
    local args = Args.action():set_from_tbl({
        interactive = true;
        method      = method;
        format      = 'json';
        session     = 'pipe';

        -- Optional user settings
        log_file    = opts.log_file;
        log_level   = opts.log_level;
        ssh_host    = opts.ssh and opts.ssh.host;
        ssh_port    = opts.ssh and opts.ssh.port;
        ssh_user    = opts.ssh and opts.ssh.user;
    }):as_string()

    local cmd = vim.trim(self.__settings.bin .. ' action ' .. args)
    log.fmt_debug('Client cmd: %s', cmd)

    --- @type JobHandle
    local handle
    handle = utils.job_start(cmd, {
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
            local msg
            if line ~= nil and line ~= "" then
                msg = vim.fn.json_decode(line)
                if self:__is_auth_msg(msg) then
                    self:__auth_handler(msg, function(out)
                        handle.write(utils.compress(vim.fn.json_encode(out)) .. '\n')
                    end)
                else
                    self:__handler(msg)
                end
            end
        end;
        on_stderr_line = function(line)
            if line ~= nil and line ~= "" then
                log.error(line)
            end
        end
    })

    -- Send our session initialization line
    -- if we are using distant
    if method == 'distant' then
        local session_line =
            'DISTANT CONNECT '
            .. opts.session.host
            .. ' '
            .. tostring(opts.session.port)
            .. ' '
            .. opts.session.key

        print('Writing "' .. session_line .. '"')
        handle.write(session_line .. '\n')
    end

    self.__state = {
        tenant = 'nvim_tenant_' .. utils.next_id();
        session = opts.session;
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

--- Authentication event handler
--- @param msg table
--- @param reply fun(msg:table)
--- @return boolean #true if okay, otherwise false
function Client:__auth_handler(msg, reply)
    local type = msg.type

    if type == 'ssh_authenticate' then
        reply({
            type = 'ssh_authenticate_answer',
            answers = self.auth.on_authenticate(msg)
        })
        return true
    elseif type == 'ssh_banner' then
        self.auth.on_info(msg.text)
        return true
    elseif type == 'ssh_host_verify' then
        reply({
            type = 'ssh_host_verify_answer',
            answer = self.auth.on_verify_host(msg.host)
        })
        return true
    elseif type == 'ssh_error' then
        self.auth.on_error(vim.inspect(msg))
        return false
    else
        self.auth.on_unknown(msg)
        return false
    end
end

--- @param msg {type:string}
--- @return boolean
function Client:__is_auth_msg(msg)
    return msg and type(msg.type) == 'string' and vim.tbl_contains({
        'ssh_authenticate',
        'ssh_banner',
        'ssh_host_verify',
        'ssh_host_verify_answer',
        'ssh_error',
    }, msg.type)
end

return Client
