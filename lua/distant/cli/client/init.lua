local log   = require('distant.log')
local state = require('distant.state')
local utils = require('distant.utils')

local Cmd     = require('distant.cli.cmd')
local api     = require('distant.cli.api')
local install = require('distant.cli.install')
local lsp     = require('distant.cli.lsp')
local term    = require('distant.cli.term')

--- @alias Destination string
--- @alias Connection string

--- Minimum version supported by the cli, also enforcing
--- version upgrades such that 0.17.x would not allow 0.18.0+
--- @type Version
local MIN_VERSION = assert(utils.parse_version('0.17.0'))

--- Represents a Cli connected to a remote machine
--- @class Cli
--- @field id string #Represents an arbitrary unique id for the cli
--- @field api CliApi #General API to perform operations remotely
--- @field auth CliAuth #Authentication-based handlers
--- @field lsp CliLsp #LSP API to spawn a process that behaves like an LSP server
--- @field term CliTerm #Terminal API to spawn a process that behaves like a terminal
--- @field __state InternalState
--- @field __settings InternalSettings
local Client = {}
Client.__index = Client

--- @class CliAuth
--- @field on_authenticate? fun(msg:CliAuthMsg):string[]
--- @field on_verify_host? fun(host:string):boolean
--- @field on_info? fun(text:string)
--- @field on_error? fun(err:string)
--- @field on_unknown? fun(x:any)

--- @class CliAuthMsg
--- @field username? string
--- @field instructions? string
--- @field prompts {prompt:string, echo:boolean}[]

--- @return CliAuth
local function make_cli_auth()
    return {
        --- @param msg CliAuthMsg
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
--- @field handle? JobHandle
--- @field callbacks table<string, InternalCallback>
--- @field destination Destination #URI representing target server
--- @field connection? Connection #ID of established connection

--- @class InternalSettings
--- @field bin string
--- @field timeout number
--- @field interval number

--- @class InternalCallback
--- @field callback fun(payload:table) @Invoked with payload from received event
--- @field multi boolean @If true, will not clear the callback after first invocation
--- @field stop fun() @When called, will stop the callback from being invoked and clear it

--- @alias LogLevel 'off'|'error'|'warn'|'info'|'debug'|'trace'

--- @class CliNewOpts
--- @field auth? CliAuth
--- @field bin? string
--- @field timeout? number
--- @field interval? number
--- @field no_install_fallback? boolean #if true, will not inject install bin path if no other works

--- Creates a new instance of our cli that is not yet connected
--- @param opts? CliNewOpts Options for use with our cli
--- @return Cli
function Cli:new(opts)
    opts = opts or {}

    local instance = {}
    setmetatable(instance, Cli)
    instance.id = 'cli_' .. tostring(utils.next_id())
    instance.api = api(instance)
    instance.lsp = lsp(instance)
    instance.term = term(instance)

    instance.auth = vim.tbl_deep_extend(
        'keep',
        opts.auth or {},
        make_cli_auth()
    )

    instance.__state = {
        handle = nil;
        callbacks = {};
        details = nil;
    }

    -- If we are not given a custom bin path, the settings bin path
    -- hasn't changed (from distant/distant.exe), and the current
    -- bin path isn't executable, then check if the install path
    -- exists and is executable and use it
    local bin = opts.bin or state.settings.cli.bin
    local is_bin_generic = bin == 'distant' or bin == 'distant.exe'
    if not opts.no_install_fallback and is_bin_generic and vim.fn.executable(bin) ~= 1 then
        bin = install.path()
    end

    instance.__settings = {
        bin = bin;
        timeout = opts.timeout or state.settings.max_timeout;
        interval = opts.interval or state.settings.timeout_interval;
    }
    return instance
end

--- Builds a new cli command to execute using the given cmd as input
--- @overload fun(cmd:BaseCmd):string
--- @param cmd BaseCmd
--- @param opts {list:boolean}
--- @return string|string[]
function Cli:build_cmd(cmd, opts)
    if not opts then
        opts = {}
    end

    if opts.list then
        local lst = cmd:as_list()
        table.insert(lst, 1, self:binary())
        return lst
    else
        return self:binary() .. ' ' .. cmd:as_string()
    end
end

--- @return boolean #true if the binary used by this cli exists and is executable
function Cli:is_executable()
    return vim.fn.executable(self.__settings.bin) == 1
end

--- @class CliInstallOpts
--- @field bin? string
--- @field reinstall? boolean
--- @field timeout? number
--- @field interval? number

--- Creates a cli, checks if the binary is available on path, and
--- installs the binary if it is not. Will also check the version and
--- attempt to install the binary if the available version fails
--- our check
--- @param opts? CliInstallOpts
--- @param cb fun(err:string|boolean, cli:Cli|nil)
function Cli:install(opts, cb)
    if not cb then
        cb = opts
        opts = {}
    end

    if not opts then
        opts = {}
    end

    local cli = Cli:new(opts)
    local has_bin = vim.fn.executable(cli.__settings.bin) == 1

    local function validate_cli()
        local version = cli:version()
        if not version then
            return cb('Unable to detect binary version')
        end
        local ok = utils.can_upgrade_version(
            MIN_VERSION,
            version,
            { allow_unstable_upgrade = true }
        )

        if ok then
            vim.schedule(function() cb(false, cli) end)
        end

        return ok
    end

    -- If the cli's binary is available, check if it's valid and
    -- if so we can exit
    if has_bin and validate_cli() then
        return
    end

    -- Otherwise, try to install to our internal location and use it
    return install.install({
        min_version = MIN_VERSION,
        reinstall = opts.reinstall,
    }, function(success, result)
        if not success then
            return cb(result)
        else
            -- Ensure that our cli's internal binary has been set
            cli.__settings.bin = result
            validate_cli()
        end
    end)
end

--- Whether or not the cli is connected to a remote server
--- @return boolean
function Cli:is_connected()
    return not (not self.__state.connection)
end

--- Returns the binary used by the cli
--- @return string path to the binary
function Cli:binary()
    return self.__settings.bin
end

--- Returns the maximum timeout in milliseconds for a request
--- @return number timeout for a request in milliseconds
function Cli:max_timeout()
    return self.__settings.timeout
end

--- Returns the time in milliseconds to wait between checking for a request to complete
--- @return number interval for a timeout for a request in milliseconds
function Cli:timeout_interval()
    return self.__settings.interval
end

--- Returns the id of the cli's connection, if it is active
--- @return Connection|nil
function Cli:connection()
    return self.__state.connection
end

--- @class LaunchOpts
--- @field destination Destination
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
---
--- @field auth? CliAuth

--- Launches a server remotely and performs authentication with the remote server
---
--- @param opts LaunchOpts
--- @param cb fun(err?:string, connection?:Connection)
--- @return JobHandle|nil
function Cli:launch(opts, cb)
    log.fmt_debug('Authenticating with options: %s', opts)
    opts = opts or {}
    vim.validate({
        destination = { opts.destination, 'string' },
        on_exit = { opts.on_exit, 'function', true },
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

    local destination = opts.destination
    local cmd = self:build_cmd(Cmd.cli.launch(destination):set_from_tbl({
        -- Optional user settings
        distant           = opts.distant;
        distant_args      = wrap_args(opts.distant_args);
        log_file          = opts.log_file;
        log_level         = opts.log_level;
        no_shell          = opts.no_shell;
        ssh               = opts.ssh;
        ssh_external      = opts.ssh_external;
        ssh_identity_file = opts.ssh_identity_file;
        ssh_port          = opts.ssh_port and tostring(opts.ssh_port);
        ssh_username      = opts.ssh_username;
    }))

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
                    -- If we want to connect after launching, do so
                    if type(opts.connect) == 'boolean' and opts.connect then
                        self:connect({ destination = destination })
                    elseif type(opts.connect) == 'function' then
                        self:connect({ destination = destination, on_exit = opts.connect })
                    end

                    -- NOTE: We have this flag for connection as for some reason the
                    --       DISTANT CONNECT line shows up twice
                    is_connected = true

                    cb(false, destination)
                elseif not is_connected then
                    self:__auth_handler(
                        vim.fn.json_decode(line),
                        function(msg)
                            handle.write(utils.compress(vim.fn.json_encode(msg)) .. '\n')
                        end,
                        opts.auth
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
--- @field destination Destination #URI representing the connection destination
--- @field on_exit? fun(exit_code:number)
--- @field method? 'distant'|'ssh'
--- @field log_file? string
--- @field log_level? LogLevel
--- @field auth? CliAuth

--- @class ConnectSshOpts
--- @field host? string
--- @field port? number
--- @field user? string

--- Connects this cli to a remote server
--- @param opts ConnectOpts
function Cli:connect(opts)
    log.fmt_debug('Starting cli with options: %s', opts)
    assert(not self:is_connected(), 'Cli is already connected!')
    opts = opts or {}

    vim.validate({
        destination = { opts.destination, 'string' },
        on_exit = { opts.on_exit, 'function', true },
        method = { opts.method, 'string', true },
        log_file = { opts.log_file, 'string', true },
        log_level = { opts.log_level, 'string', true },
    })

    if vim.fn.executable(self.__settings.bin) ~= 1 then
        log.fmt_error('Executable %s is not on path', self.__settings.bin)
        return
    end

    --- @type 'distant'|'ssh'
    local method = opts.method or 'distant'
    local cmd = self:build_cmd(Cmd.action():set_from_tbl({
        interactive = true;
        method      = method;
        format      = 'json';
        session     = 'pipe';

        -- Optional user settings
        log_file  = opts.log_file;
        log_level = opts.log_level;
    }))

    log.fmt_debug('Cli cmd: %s', cmd)

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
            -- This is a termination signal which happens
            -- when neovim exits and kills a child process,
            -- which we don't want to print out as part
            -- of our logging, so we skip this by treating
            -- it as a success instead
            if code == 143 then
                if type(opts.on_exit) == 'function' then
                    opts.on_exit(0)
                end
            else
                log.fmt_error(
                    'Connect failed (%s): %s',
                    tostring(code),
                    errors.description_by_code(code) or '???'
                )

                if type(opts.on_exit) == 'function' then
                    opts.on_exit(code)
                end
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
                    end, opts.auth)
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

        handle.write(session_line .. '\n')
    end

    self.__state = {
        handle = handle;
        callbacks = {};
        details = {
            type = method,
            tcp = opts.session,
            ssh = opts.ssh,
        };
    }
end

--- Stops an instance of distant if running by killing the process
--- and resetting state
function Cli:stop()
    if self.__state.handle ~= nil then
        self.__state.handle.stop()
    end
    self.__state.handle = nil
    self.__state.callbacks = {}
    self.__state.details = nil
end

--- @class CliMsg
--- @field type string
--- @field data table

--- @alias OneOrMoreMsgs CliMsg|CliMsg[]

--- @class SendOpts
--- @field unaltered? boolean @when true, the callback will not be wrapped in the situation where there is
---                           a single request payload entry to then return a single response payload entry
--- @field multi? boolean @when true, the callback may be triggered multiple times and will not be cleared
---                       within the Cli upon receiving an event. Instead, a function is returned that will
---                       be called when we want to stop receiving events whose origin is this message

--- Send one or more messages to the remote machine, invoking the provided callback with the
--- response once it is received
---
--- @param msgs OneOrMoreMsgs
--- @param opts? SendOpts
--- @param cb fun(data:table, stop:fun()|nil)
function Cli:send(msgs, opts, cb)
    if type(cb) ~= 'function' then
        cb = opts
        opts = {}
    end

    if not opts then
        opts = {}
    end

    log.fmt_trace('Cli:send(%s, %s, _)', msgs, opts)
    assert(self:is_connected(), 'Cli is not connected!')

    local payload = msgs
    if not vim.tbl_islist(payload) then
        payload = { payload }
    end

    -- Build a full message that wraps the provided message as the payload and
    -- includes an id that our cli uses when relaying a response for the
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
function Cli:send_wait(msgs, opts)
    opts = opts or {}
    log.fmt_trace('Cli:send_wait(%s, %s)', msgs, opts)
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
function Cli:send_wait_ok(msgs, opts)
    opts = opts or {}
    log.fmt_trace('Cli:send_wait_ok(%s, %s)', msgs, opts)
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
function Cli:__handler(msg)
    assert(type(msg) == 'table', 'msg must be a table')
    log.fmt_trace('Cli:__handler(%s)', msg)

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
--- @param auth? CliAuth
--- @return boolean #true if okay, otherwise false
function Cli:__auth_handler(msg, reply, auth)
    local type = msg.type

    --- @type CliAuth
    auth = vim.tbl_deep_extend('keep', auth or {}, self.auth)

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
function Cli:__is_auth_msg(msg)
    return msg and type(msg.type) == 'string' and vim.tbl_contains({
        'challenge',
        'verify',
        'info',
        'error',
    }, msg.type)
end

return Cli
