local auth             = require('distant-core.auth')
local builder          = require('distant-core.builder')
local Client           = require('distant-core.client')
local Destination      = require('distant-core.destination')
local log              = require('distant-core.log')
local utils            = require('distant-core.utils')

local DEFAULT_TIMEOUT  = 1000
local DEFAULT_INTERVAL = 100

--- @alias distant.core.manager.ConnectionId integer # 32-bit unsigned integer
--- @alias distant.core.manager.ConnectionMap table<distant.core.manager.ConnectionId, distant.core.Destination>

--- @param connection any
--- @param opts? {allow_nil?:boolean, convert?:boolean}
--- @return distant.core.manager.ConnectionId|nil
local function assert_connection_opts(connection, opts)
    opts = opts or {}
    if connection ~= nil then
        if opts.convert then
            connection = tonumber(connection)
        end

        assert(type(connection) == 'number', 'connection must be a 32-bit unsigned integer')
    else
        assert(opts.allow_nil, 'connection cannot be nil')
    end
    return connection
end

--- @param connection any
--- @return distant.core.manager.ConnectionId
local function assert_connection(connection)
    local x = assert_connection_opts(connection)

    --- @cast x distant.core.manager.ConnectionId
    return x
end

--- Represents a distant manager
--- @class distant.core.Manager
--- @field clients table<string, distant.core.Client> #mapping of id -> client
--- @field private config distant.core.manager.Config
--- @field private connections distant.core.manager.ConnectionMap #mapping of id -> destination
local M   = {}
M.__index = M

--- @class distant.core.manager.Config
--- @field binary string #path to distant binary to use
--- @field network distant.core.manager.Network #manager-specific network settings

--- @class distant.core.manager.Network
--- @field unix_socket? string #path to the unix socket of the manager
--- @field windows_pipe? string #name of the windows pipe of the manager

--- Creates a new instance of a distant manager
--- @param opts distant.core.manager.Config
--- @return distant.core.Manager
function M:new(opts)
    opts = opts or {}

    local instance = {}
    setmetatable(instance, M)
    instance.config = {
        binary = opts.binary,
        network = vim.deepcopy(opts.network) or {},
    }
    instance.connections = {}
    instance.clients = {}

    return instance
end

--- Returns a copy of this manager's network settings.
--- @return distant.core.manager.Network
function M:network()
    return vim.deepcopy(self.config.network)
end

--- @param connection distant.core.manager.ConnectionId
--- @return boolean
function M:has_connection(connection)
    return self.connections[assert_connection(connection)] ~= nil
end

--- @param connection distant.core.manager.ConnectionId
--- @return distant.core.Destination|nil #destination if connection exists
function M:connection_destination(connection)
    return self.connections[assert_connection(connection)]
end

--- @param connection distant.core.manager.ConnectionId
--- @return distant.core.Client|nil #client wrapper around connection if it exists, or nil
function M:client(connection)
    connection = assert_connection(connection)
    if self:has_connection(connection) then
        -- If no client has been made for this connection yet, create one.
        --
        -- We do this to avoid creating more than one API underneath, which
        -- results in more than one transport spawning.
        if not self.clients[connection] then
            self.clients[connection] = Client:new({
                binary = self.config.binary,
                network = {
                    connection = connection,
                    unix_socket = self.config.network.unix_socket,
                    windows_pipe = self.config.network.windows_pipe,
                },
            })
        end

        return self.clients[connection]
    end
end

--- @class distant.core.manager.Info
--- @field id distant.core.manager.ConnectionId
--- @field destination distant.core.Destination
--- @field options string

--- Retrieves information about a connection maintained by this manager.
--- @param opts {connection:distant.core.manager.ConnectionId, timeout?:number, interval?:number}
--- @param cb fun(err?:string, info?:distant.core.manager.Info)
--- @return string|nil err, distant.core.manager.Info|nil info
function M:info(opts, cb)
    opts = opts or {}

    local cmd = builder
        .manager
        .info(opts.connection)
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

    local error_lines = {}
    utils.job_start(cmd, {
        on_success = function()
            cb(nil)
        end,
        on_failure = function()
            cb('Failed to make selection')
        end,
        on_stdout_line = function(line)
            --- @type {id:distant.core.manager.ConnectionId, destination:string, options:string}
            local msg = assert(vim.fn.json_decode(line), 'Invalid JSON from line')

            --- @type distant.core.manager.Info
            local info = {
                id = msg.id,
                destination = Destination:parse(msg.destination),
                options = msg.options,
            }
            return cb(nil, info)
        end,
        on_stderr_line = function(line)
            if line ~= nil then
                table.insert(error_lines, line)
            end
        end,
    })

    if rx then
        --- @type boolean, string|nil, distant.core.manager.Info|nil
        local _, err, info = pcall(rx)
        return err, info
    end
end

--- Kills a connection maintained by this manager, removing it from the manager's tracker.
--- @param opts {connection:distant.core.manager.ConnectionId, timeout?:number, interval?:number}
--- @param cb fun(err?:string, ok?:{type:'ok'})
--- @return string|nil err, {type:'ok'}|nil ok
function M:kill(opts, cb)
    opts = opts or {}

    local cmd = builder
        .manager
        .kill(opts.connection)
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

    local error_lines = {}
    utils.job_start(cmd, {
        on_success = function()
            cb(nil)
        end,
        on_failure = function()
            cb('Failed to make selection')
        end,
        on_stdout_line = function(line)
            --- @type {type:'ok'}
            local msg = assert(vim.fn.json_decode(line), 'Invalid JSON from line')

            if not type(msg) == 'table' or msg.type == 'ok' then
                return cb('Invalid response: ' .. vim.inspect(msg), nil)
            end

            return cb(nil, msg)
        end,
        on_stderr_line = function(line)
            if line ~= nil then
                table.insert(error_lines, line)
            end
        end,
    })

    if rx then
        --- @type boolean, string|nil, distant.core.manager.Info|nil
        local _, err, info = pcall(rx)
        return err, info
    end
end

--- @class distant.core.manager.SelectOpts
--- @field connection? distant.core.manager.ConnectionId
--- @field on_choices? fun(opts:{choices:string[], current:number}):number|nil #If provided,
--- @field timeout? number
--- @field interval? number

--- @class distant.core.manager.ConnectionSelector
--- @field choices distant.core.Destination[]
--- @field current number
--- @field select fun(choice?:number, cb?:fun(err?:string)) #Perform a selection, or cancel if choice = nil

--- Changes the selected connection used as default by the manager
--- @param opts distant.core.manager.SelectOpts
--- @param cb fun(err?:string, selector?:distant.core.manager.ConnectionSelector) #Selector will be provided if no connection provided in opts
--- @return string|nil err, distant.core.manager.ConnectionSelector|nil selector
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

    --- @type distant.core.utils.JobHandle
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
            --- @type {type:'select', choices:string[], current:number}
            local msg = assert(vim.fn.json_decode(line), 'Invalid JSON from line')

            if msg.type == 'select' then
                return cb(nil, {
                    --- @param choice string
                    choices = vim.tbl_map(function(choice)
                        return Destination:parse(choice)
                    end, msg.choices),
                    current = msg.current,
                    select = function(choice, new_cb)
                        -- Update our cb triggered when process exits to now be the selector's callback
                        if new_cb then
                            cb = new_cb
                        end

                        --- @type {type: 'selected', choice:number|nil }
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
        --- @type boolean, string|nil, distant.core.manager.ConnectionSelector|nil
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

--- @class distant.core.manager.ListenOpts
--- @field access? 'owner'|'group'|'anyone' #access level for the unix socket or windows pipe
--- @field config? string #alternative config path to use
--- @field daemon? boolean #if true, will detach the manager from this neovim instance
--- @field log_file? string #alternative log file path to use
--- @field log_level? distant.core.log.Level #alternative log level to use
--- @field user? boolean #if true, specifies that the manager should listen with user-level permissions (only applies if no explicit socket or pipe name provided)

--- Start a new manager that is listening on the local unix socket or windows pipe
--- defined by the network configuration
--- @param opts distant.core.manager.ListenOpts
--- @param cb fun(err?:string) #invoked when the manager exits
--- @return distant.core.utils.JobHandle #handle of listening manager job
function M:listen(opts, cb)
    opts = opts or {}

    -- If true, will result in the spawned process exiting after forking
    -- the manager process
    --- @type boolean
    local daemon = opts.daemon == true or false

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
            daemon       = daemon,
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

--- @class distant.core.manager.LaunchOpts
--- @field destination string #uri representing the remote server
---
--- @field auth? distant.core.auth.Handler #authentication handler to use
--- @field cache? string #alternative cache path to use
--- @field config? string #alternative config path to use
--- @field distant? string #alternative path to distant binary (on remote machine) to use
--- @field distant_bind_server? 'any'|'ssh'|string #control the IP address that the server binds to
--- @field distant_args? string|string[] #additional arguments to supply to distant binary on remote machine
--- @field log_file? string #alternative log file path to use
--- @field log_level? string #alternative log level to use
--- @field options? string|table<string, any> #additional options tied to a specific destination handler
---
--- @field timeout? number
--- @field interval? number

--- Launches a server remotely and performs authentication using the given manager
--- @param opts distant.core.manager.LaunchOpts
--- @param cb? fun(err?:string, client?:distant.core.Client)
--- @return string|nil err, distant.core.Client|nil client
function M:launch(opts, cb)
    opts = opts or {}
    log.fmt_debug('Launching with options: %s', opts)

    if vim.fn.executable(self.config.binary) ~= 1 then
        log.fmt_error('Executable %s is not on path', self.config.binary)
        return
    end

    local rx
    if not cb then
        cb, rx = utils.oneshot_channel(
            opts.timeout or DEFAULT_TIMEOUT,
            opts.interval or DEFAULT_INTERVAL
        )
    end

    assert(cb, 'Impossible: cb cannot be nil at this point')

    --- @param text string|string[]|nil
    --- @return string|nil
    local wrap_args = function(text)
        if type(text) == 'table' then
            text = table.concat(text, ' ')
        elseif type(text) == 'string' then
            text = text
        else
            return
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

    local destination = Destination:parse(opts.destination)
    log.fmt_trace('Launch destination: %s', destination)
    local cmd = builder
        .launch(destination:as_string())
        :set_from_tbl({
            -- Explicitly set to use JSON for communication and point to
            -- manager's unix socket or windows pipe
            format              = 'json',
            unix_socket         = self.config.network.unix_socket,
            windows_pipe        = self.config.network.windows_pipe,
            -- Optional user settings
            cache               = opts.cache,
            config              = opts.config,
            distant             = opts.distant,
            distant_bind_server = opts.distant_bind_server,
            distant_args        = wrap_args(opts.distant_args) or false,
            log_file            = opts.log_file,
            log_level           = opts.log_level,
            options             = build_options(opts.options) or false,
        })
        :as_list()
    table.insert(cmd, 1, self.config.binary)

    log.fmt_debug('Launch cmd: %s', cmd)
    auth.spawn({
        cmd = cmd,
        auth = opts.auth,
        skip = function(msg)
            return msg.type ~= 'launched'
        end,
    }, function(err, result)
        if err then
            return cb(err)
        end

        --- @type distant.core.manager.ConnectionId|nil
        local id = tonumber(vim.tbl_get(result or {}, 'msg', 'id'))
        if id == nil then
            cb('Invalid result failed to yield connection id: ' .. vim.inspect(result))
            return
        end

        -- Update manager to reflect connection
        self.connections[id] = destination

        return cb(nil, self:client(id))
    end)

    if rx then
        --- @type boolean, string|nil, distant.core.Client|nil
        local _, err, client = pcall(rx)
        return err, client
    end
end

--- @class distant.core.manager.ConnectOpts
--- @field destination string #uri used to identify server's location
---
--- @field auth? distant.core.auth.Handler #authentication handler to use
--- @field cache? string #alternative cache path to use
--- @field config? string #alternative config path to use
--- @field log_file? string #alternative log file path to use
--- @field log_level? string #alternative log level to use
--- @field options? string|table<string, any> #additional options tied to a specific destination handler
---
--- @field timeout? number
--- @field interval? number

--- Connects to a remote server using the given manager
--- @param opts distant.core.manager.ConnectOpts
--- @param cb fun(err?:string, client?:distant.core.Client)
--- @return string|nil err, distant.core.Client|nil client
function M:connect(opts, cb)
    opts = opts or {}
    log.fmt_debug('Connecting with options: %s', opts)

    if vim.fn.executable(self.config.binary) ~= 1 then
        log.fmt_error('Executable %s is not on path', self.config.binary)
        return
    end

    local rx
    if not cb then
        cb, rx = utils.oneshot_channel(
            opts.timeout or DEFAULT_TIMEOUT,
            opts.interval or DEFAULT_INTERVAL
        )
    end

    local destination = Destination:parse(opts.destination)
    local cmd = builder
        .connect(destination:as_string())
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
    auth.spawn({
        cmd = cmd,
        auth = opts.auth,
        skip = function(msg)
            return msg.type ~= 'connected'
        end,
    }, function(err, result)
        if err then
            return cb(err)
        end

        --- @type distant.core.manager.ConnectionId|nil
        local id = tonumber(vim.tbl_get(result or {}, 'msg', 'id'))
        if id == nil then
            cb('Invalid result failed to yield connection id: ' .. vim.inspect(result))
            return
        end

        -- Update manager to reflect connection
        self.connections[id] = destination

        return cb(nil, self:client(id))
    end)

    if rx then
        --- @type boolean, string|nil, distant.core.Client|nil
        local _, err, client = pcall(rx)
        return err, client
    end
end

--- @class distant.core.manager.ListOpts
--- @field auth? distant.core.auth.Handler # authentication handler to use
--- @field cache? string # alternative cache path to use
--- @field config? string # alternative config path to use
--- @field log_file? string # alternative log file path to use
--- @field log_level? string # alternative log level to use
--- @field refresh? boolean # (default true) if true, will use the updated list to update the internally-tracked clients
--- @field timeout? number
--- @field interval? number

--- Retrieves a list of connections being managed. Will also update the
--- internally-tracked state to reflect these connections.
---
--- @param opts distant.core.manager.ListOpts
--- @param cb fun(err?:string, connections?:distant.core.manager.ConnectionMap)
--- @return string|nil err, distant.core.manager.ConnectionMap|nil connections
function M:list(opts, cb)
    log.fmt_trace('Manager:list(%s, _)', opts)

    if vim.fn.executable(self.config.binary) ~= 1 then
        log.fmt_error('Executable %s is not on path', self.config.binary)
        return
    end

    local rx
    if not cb then
        cb, rx = utils.oneshot_channel(
            opts.timeout or DEFAULT_TIMEOUT,
            opts.interval or DEFAULT_INTERVAL
        )
    end

    local cmd = builder
        .manager
        .list()
        :set_from_tbl({
            format       = 'json',
            unix_socket  = self.config.network.unix_socket,
            windows_pipe = self.config.network.windows_pipe,
            -- Optional user settings
            cache        = opts.cache,
            config       = opts.config,
            log_file     = opts.log_file,
            log_level    = opts.log_level,
        })
        :as_list()
    table.insert(cmd, 1, self.config.binary)

    log.fmt_debug('Manager list cmd: %s', cmd)
    auth.spawn({
        cmd = cmd,
        auth = opts.auth,
    }, function(err, result)
        if err then
            return cb(err)
        end

        if result == nil then
            return cb('Invalid result failed to yield connections')
        end

        --- @type distant.core.manager.ConnectionMap
        local connections = {}

        for id, destination_str in pairs(result.msg) do
            if type(id) == 'string' and type(destination_str) == 'string' then
                local connection = assert_connection_opts(id, { convert = true })
                --- @cast connection distant.core.manager.ConnectionId
                local destination = Destination:try_parse(destination_str)
                if destination then
                    connections[connection] = destination
                end
            end
        end

        -- Update our stateful tracking of connections (default is to refresh)
        if opts.refresh == nil or opts.refresh == true then
            self.connections = connections
        end

        return cb(nil, connections)
    end)

    if rx then
        --- @type boolean, string|nil, distant.core.manager.ConnectionMap|nil
        local _, err, connections = pcall(rx)
        return err, connections
    end
end

return M
