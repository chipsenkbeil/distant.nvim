local auth             = require('distant-core.auth')
local builder          = require('distant-core.builder')
local Client           = require('distant-core.client')
local log              = require('distant-core.log')
local utils            = require('distant-core.utils')

local DEFAULT_TIMEOUT  = 1000
local DEFAULT_INTERVAL = 100

--- Represents a distant manager
--- @class distant.Manager
--- @field private config distant.manager.Config
--- @field private connections table<string, {destination:string}> #mapping of id -> destination
local M                = {}
M.__index              = M

--- @class distant.manager.Config
--- @field binary string #path to distant binary to use
--- @field network distant.manager.Network #manager-specific network settings

--- @class distant.manager.Network
--- @field unix_socket? string #path to the unix socket of the manager
--- @field windows_pipe? string #name of the windows pipe of the manager

--- Creates a new instance of a distant manager
--- @param opts distant.manager.Config
--- @return distant.Manager
function M:new(opts)
    opts = opts or {}

    local instance = {}
    setmetatable(instance, M)
    instance.config = {
        binary = opts.binary,
        network = vim.deepcopy(opts.network) or {},
    }
    instance.connections = {}

    return instance
end

--- @param connection string #id of the connection being managed
--- @return boolean
function M:has_connection(connection)
    return self.connections[connection] ~= nil
end

--- @param connection string #id of the connection being managed
--- @return string|nil #destination if connection exists
function M:connection_destination(connection)
    local c = self.connections[connection]
    if c then
        return c.destination
    end
end

--- @param connection string #id of the connection being managed
--- @return distant.Client|nil #client wrapper around connection if it exists, or nil
function M:client(connection)
    if self:has_connection(connection) then
        return Client:new({
            binary = self.config.binary,
            network = vim.tbl_extend(
                'keep',
                { connection = connection },
                self.config.network
            ),
        })
    end
end

--- @class distant.manager.SelectOpts
--- @field connection? string #If provided, will set manager's default connection to this connection
--- @field on_choices? fun(opts:{choices:string[], current:number}):number|nil #If provided,
--- @field timeout? number
--- @field interval? number

--- @class distant.manager.ConnectionSelector
--- @field choices string[]
--- @field current number
--- @field select fun(choice?:number, cb?:fun(err?:string)) #Perform a selection, or cancel if choice = nil

--- Changes the selected connection used as default by the manager
--- @param opts distant.manager.SelectOpts
--- @param cb fun(err?:string, selector?:distant.manager.ConnectionSelector) #Selector will be provided if no connection provided in opts
--- @return string|nil, distant.manager.ConnectionSelector|nil
function M:select(opts, cb)
    opts = opts or {}

    local cmd = builder
        .manager
        .select(opts.connection)
        :set_format('json')
        :set_from_tbl(self.config.network)
        :as_list()
    table.insert(cmd, 1, self.config.binary)

    local rx
    if not cb then
        cb, rx = utils.oneshot_channel(
            opts.timeout or DEFAULT_TIMEOUT,
            opts.interval or DEFAULT_INTERVAL
        )
    end

    assert(cb, 'Impossible: cb cannot be nil at this point')

    --- @type distant-core.utils.JobHandle
    local handle
    local error_lines = {}
    handle = utils.job_start(cmd, {
        on_success = function()
            cb(nil)
        end,
        on_failure = function()
            cb('Failed to make selection')
        end,
        on_stdout_line = function(line)
            local msg = assert(vim.fn.json_decode(line), 'Invalid JSON from line')
            if msg.type == 'select' then
                return cb(nil, {
                    choices = msg.choices,
                    current = msg.current,
                    select = function(choice, new_cb)
                        -- Update our cb triggered when process exits to now be the selector's callback
                        if new_cb then
                            cb = new_cb
                        end

                        --- @diagnostic disable-next-line:redefined-local
                        local msg = { type = 'selected', choice = choice }
                        handle:write(utils.compress(vim.fn.json_encode(msg)) .. '\n')
                    end,
                })
            end
        end,
        on_stderr_line = function(line)
            if line ~= nil then
                table.insert(error_lines, line)
            end
        end,
    })

    if rx then
        --- @type boolean, string|nil, distant.manager.ConnectionSelector|nil
        local _, err, selector = pcall(rx)
        return err, selector
    end
end

--- Check if defined manager is listening. Note that this can be the case even when
--- we have not spawned the manager ourselves
--- @param opts {timeout?:number, interval?:number}
--- @param cb? fun(value:boolean)
--- @return boolean|nil
function M:is_listening(opts, cb)
    opts = opts or {}

    local cmd = builder
        .manager
        .list()
        :set_from_tbl(self.config.network)
        :as_list()
    table.insert(cmd, 1, self.config.binary)

    local rx
    if not cb then
        cb, rx = utils.oneshot_channel(
            opts.timeout or DEFAULT_TIMEOUT,
            opts.interval or DEFAULT_INTERVAL
        )
    end

    assert(cb, 'Impossible: cb cannot be nil at this point')

    utils.job_start(cmd, {
        on_success = function()
            cb(true)
        end,
        on_failure = function()
            cb(false)
        end
    })

    if rx then
        --- @type boolean, string|boolean
        local status, result = pcall(rx)
        return status and result == true
    end
end

--- Waits until the manager is listening, up to timeout
--- @param opts {timeout?:number, interval?:number}
--- @return boolean
function M:wait_for_listening(opts)
    opts = opts or {}

    local timeout = opts.timeout or DEFAULT_TIMEOUT
    local interval = opts.interval or DEFAULT_INTERVAL

    -- Continually check listening status until timeout
    local status = vim.fn.wait(
        timeout,
        function()
            return self:is_listening({ timeout = timeout, interval = interval })
        end,
        interval
    )

    return status == 0
end

--- @class distant.manager.ListenOpts
--- @field access? 'owner'|'group'|'anyone' #access level for the unix socket or windows pipe
--- @field config? string #alternative config path to use
--- @field log_file? string #alternative log file path to use
--- @field log_level? string #alternative log level to use
--- @field user? boolean #if true, specifies that the manager should listen with user-level permissions (only applies if no explicit socket or pipe name provided)

--- Start a new manager that is listening on the local unix socket or windows pipe
--- defined by the network configuration
--- @param opts distant.manager.ListenOpts
--- @param cb fun(err?:string) #invoked when the manager exits
--- @return distant-core.utils.JobHandle #handle of listening manager job
function M:listen(opts, cb)
    opts = opts or {}

    local cmd = builder
        .manager
        .listen()
        :set_from_tbl({
            -- Explicitly point to manager's unix socket or windows pipe
            unix_socket  = self.config.network.unix_socket,
            windows_pipe = self.config.network.windows_pipe,
            -- Optional user settings
            access       = opts.access,
            config       = opts.config,
            log_file     = opts.log_file,
            log_level    = opts.log_level,
            user         = opts.user,
        })
        :as_list()
    table.insert(cmd, 1, self.config.binary)

    local handle, error_lines
    error_lines = {}
    handle = utils.job_start(cmd, {
        on_success = function()
            if cb then
                return cb(nil)
            end
        end,
        on_failure = function(code)
            local error_msg = '???'
            if not vim.tbl_isempty(error_lines) then
                error_msg = table.concat(error_lines, '\n')
            end

            error_msg = 'Failed (' .. tostring(code) .. '): ' .. error_msg

            -- NOTE: Don't trigger if code is 143 as that is neovim terminating the manager on exit
            if cb and code ~= 143 then
                return cb(error_msg)
            end
        end,
        on_stdout_line = function()
        end,
        on_stderr_line = function(line)
            if line ~= nil and cb then
                table.insert(error_lines, line)
            end
        end,
    })
    return handle
end

--- @param opts string|table<string, any> #options to build into a string list
--- @return string|nil #options in the form of key="value",key2="value2"
local function build_options(opts)
    if type(opts) == 'string' then
        return opts
    elseif type(opts) == 'table' then
        local s = ''
        local clean_value

        for key, value in pairs(opts) do
            clean_value = tostring(value):gsub('\\', '\\\\'):gsub('"', '\\"')
            s = s .. tostring(key) .. '="' .. clean_value .. '",'
        end

        return s
    end
end

--- @class distant.manager.LaunchOpts
--- @field destination string #uri representing the remote server
---
--- @field auth? distant.auth.Handler #authentication handler to use
--- @field config? string #alternative config path to use
--- @field cache? string #alternative cache path to use
--- @field distant? string #alternative path to distant binary (on remote machine) to use
--- @field distant_args? string|string[] #additional arguments to supply to distant binary on remote machine
--- @field log_file? string #alternative log file path to use
--- @field log_level? string #alternative log level to use
--- @field no_shell? boolean #if true, will not attempt to execute distant binary within a shell on the remote machine
--- @field options? string|table<string, any> #additional options tied to a specific destination handler

--- Launches a server remotely and performs authentication using the given manager
--- @param opts distant.manager.LaunchOpts
--- @param cb fun(err?:string, client?:distant.Client)
--- @return distant-core.utils.JobHandle|nil
function M:launch(opts, cb)
    opts = opts or {}
    log.fmt_debug('Launching with options: %s', opts)

    if vim.fn.executable(self.config.binary) ~= 1 then
        log.fmt_error('Executable %s is not on path', self.config.binary)
        return
    end

    local wrap_args = function(text)
        if vim.tbl_islist(text) then
            text = table.concat(text, ' ')
        else
            text = tostring(text)
        end

        local quote = '"'
        text = vim.trim(text):gsub('"', '\"')

        -- If text empty, exit
        if #text == 0 then
            return text
        end

        if not vim.startswith(text, quote) then
            text = quote .. text
        end

        if not vim.endswith(text, quote) then
            text = text .. quote
        end

        return text
    end

    local destination = opts.destination
    log.fmt_trace('Launch destination: %s', destination)
    local cmd = builder
        .launch(destination)
        :set_from_tbl({
            -- Explicitly set to use JSON for communication and point to
            -- manager's unix socket or windows pipe
            format       = 'json',
            unix_socket  = self.config.network.unix_socket,
            windows_pipe = self.config.network.windows_pipe,
            -- Optional user settings
            cache        = opts.cache,
            config       = opts.config,
            distant      = opts.distant,
            distant_args = wrap_args(opts.distant_args),
            log_file     = opts.log_file,
            log_level    = opts.log_level,
            no_shell     = opts.no_shell,
            options      = build_options(opts.options) or '',
        })
        :as_list()
    table.insert(cmd, 1, self.config.binary)

    log.fmt_debug('Launch cmd: %s', cmd)
    return auth.spawn({
        cmd = cmd,
        auth = opts.auth,
    }, function(err, connection)
        if err then
            return cb(err)
        end

        assert(connection, 'Connection nil while error is nil!')

        -- Update manager to reflect connection
        self.connections[connection] = {
            destination = destination
        }

        return cb(nil, self:client(connection))
    end)
end

--- @class distant.manager.ConnectOpts
--- @field destination string #uri used to identify server's location
---
--- @field auth? distant.auth.Handler #authentication handler to use
--- @field config? string #alternative config path to use
--- @field cache? string #alternative cache path to use
--- @field log_file? string #alternative log file path to use
--- @field log_level? string #alternative log level to use
--- @field options? string|table<string, any> #additional options tied to a specific destination handler

--- Connects to a remote server using the given manager
--- @param opts distant.manager.ConnectOpts
--- @param cb fun(err?:string, client?:distant.Client)
--- @return distant-core.utils.JobHandle|nil
function M:connect(opts, cb)
    opts = opts or {}
    log.fmt_debug('Connecting with options: %s', opts)

    if vim.fn.executable(self.config.binary) ~= 1 then
        log.fmt_error('Executable %s is not on path', self.config.binary)
        return
    end

    local destination = opts.destination
    local cmd = builder
        .connect(destination)
        :set_from_tbl({
            -- Explicitly set to use JSON for communication and point to
            -- manager's unix socket or windows pipe
            format       = 'json',
            unix_socket  = self.config.network.unix_socket,
            windows_pipe = self.config.network.windows_pipe,
            -- Optional user settings
            cache        = opts.cache,
            config       = opts.config,
            log_file     = opts.log_file,
            log_level    = opts.log_level,
            options      = build_options(opts.options) or '',
        })
        :as_list()
    table.insert(cmd, 1, self.config.binary)

    log.fmt_debug('Connect cmd: %s', cmd)
    return auth.spawn({
        cmd = cmd,
        auth = opts.auth,
    }, function(err, connection)
        if err then
            return cb(err)
        end

        assert(connection, 'Connection nil while error is nil!')

        -- Update manager to reflect connection
        self.connections[connection] = {
            destination = destination
        }

        return cb(nil, self:client(connection))
    end)
end

return M
