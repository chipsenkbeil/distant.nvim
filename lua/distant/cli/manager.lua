local log = require('distant.log')
local utils = require('distant.utils')

local auth = require('distant.cli.manager.auth')
local Client = require('distant.cli.client')
local Cmd = require('distant.cli.cmd')

local DEFAULT_TIMEOUT = 15000
local DEFAULT_INTERVAL = 100

--- Represents a distant manager
--- @class Manager
--- @field config ManagerConfig
--- @field connections table<string, string> #mapping of id -> destination
local Manager = {}
Manager.__index = Manager

--- @class ManagerConfig
--- @field binary string #path to distant binary to use
--- @field network ManagerNetwork #manager-specific network settings

--- @class ManagerNetwork
--- @field unix_socket string|nil #path to the unix socket of the manager
--- @field windows_pipe string|nil #name of the windows pipe of the manager

--- Creates a new instance of a distant manager
--- @param opts ManagerConfig
--- @return Manager
function Manager:new(opts)
    opts = opts or {}

    local instance = {}
    setmetatable(instance, Manager)
    instance.config = {
        binary = opts.binary,
        network = vim.deepcopy(opts.network) or {},
    }
    instance.connections = {}

    return instance
end

--- @param connection string #id of the connection being managed
--- @return boolean
function Manager:has_connection(connection)
    return self.connections[connection] ~= nil
end

--- @param connection string #id of the connection being managed
--- @return Client|nil #client wrapper around connection if it exists, or nil
function Manager:client(connection)
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

--- Check if defined manager is listening. Note that this can be the case even when
--- we have not spawned the manager ourselves
--- @param opts {timeout:number|nil, interval:number|nil}
--- @return boolean
function Manager:is_listening(opts)
    local cmd = Cmd.manager.list():set_from_tbl(self.config.network)
    table.insert(cmd, 0, self.config.binary)

    local tx, rx = utils.oneshot_channel(
        opts.timeout or DEFAULT_TIMEOUT,
        opts.interval or DEFAULT_INTERVAL
    )
    utils.job_start(cmd, {
        on_success = function()
            tx(true)
        end,
        on_failure = function()
            tx(false)
        end
    })

    local err, result = rx()
    return (not err) and result
end

--- @class ManagerListenOpts
--- @field access 'owner'|'group'|'anyone'|nil #access level for the unix socket or windows pipe
--- @field config string|nil #alternative config path to use
--- @field log_file string|nil #alternative log file path to use
--- @field log_level string|nil #alternative log level to use
--- @field user boolean|nil #if true, specifies that the manager should listen with user-level permissions (only applies if no explicit socket or pipe name provided)

--- Start a new manager that is listening on the local unix socket or windows pipe
--- defined by the network configuration
--- @param opts ManagerListenOpts
--- @param cb fun(err:string|nil) #invoked when the manager exits
--- @return JobHandle #handle of listening manager job
function Manager:listen(opts, cb)
    local cmd = Cmd.manager.listen():set_from_tbl({
        -- Explicitly point to manager's unix socket or windows pipe
        unix_socket  = self.config.network.unix_socket,
        windows_pipe = self.config.network.windows_pipe,

        -- Optional user settings
        access    = opts.access,
        config    = opts.config,
        log_file  = opts.log_file,
        log_level = opts.log_level,
        user      = opts.user,
    }):as_list()
    table.insert(cmd, 0, self.config.binary)

    local handle, error_lines
    error_lines = {}
    handle = utils.job_start(cmd, {
        on_success = function()
            return cb(nil)
        end,
        on_failure = function(code)
            local error_msg = '???'
            if not vim.tbl_isempty(error_lines) then
                error_msg = table.concat(error_lines, '\n')
            end

            error_msg = 'Failed (' .. tostring(code) .. '): ' .. error_msg
            return cb(error_msg)
        end,
        on_stdout_line = function()
        end,
        on_stderr_line = function(line)
            if line ~= nil then
                table.insert(error_lines, line)
            end
        end,
    })
    return handle
end

--- @class ManagerLaunchOpts
--- @field destination string #uri representing the remote server
---
--- @field auth AuthHandler|nil #authentication handler to use
--- @field config string|nil #alternative config path to use
--- @field cache string|nil #alternative cache path to use
--- @field distant string|nil #alternative path to distant binary (on remote machine) to use
--- @field distant_args string|string[]|nil #additional arguments to supply to distant binary on remote machine
--- @field log_file string|nil #alternative log file path to use
--- @field log_level string|nil #alternative log level to use
--- @field no_shell boolean|nil #if true, will not attempt to execute distant binary within a shell on the remote machine
--- @field ssh string|nil #alternative path to ssh binary (if executing external process)
--- @field ssh_external boolean|nil #if true, will execute an external ssh process instead of using native library
--- @field ssh_identity_file string|nil #location of identity file to use with ssh
--- @field ssh_port number|nil #alternative ssh port to use instead of 22
--- @field ssh_username string|nil #alternative ssh username to use instead of the current user

--- Launches a server remotely and performs authentication using the given manager
--- @param opts ManagerLaunchOpts
--- @param cb fun(err:string|nil, client:Client|nil)
--- @return JobHandle|nil
function Manager:launch(opts, cb)
    opts = opts or {}
    log.fmt_debug('Launching with options: %s', opts)

    if vim.fn.executable(self.config.binary) ~= 1 then
        log.fmt_error('Executable %s is not on path', self.config.binary)
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
    local cmd = Cmd.client.launch(destination):set_from_tbl({
        -- Explicitly set to use JSON for communication and point to
        -- manager's unix socket or windows pipe
        format       = 'json',
        unix_socket  = self.config.network.unix_socket,
        windows_pipe = self.config.network.windows_pipe,

        -- Optional user settings
        cache             = opts.cache,
        config            = opts.config,
        distant           = opts.distant,
        distant_args      = wrap_args(opts.distant_args),
        log_file          = opts.log_file,
        log_level         = opts.log_level,
        no_shell          = opts.no_shell,
        ssh               = opts.ssh,
        ssh_external      = opts.ssh_external,
        ssh_identity_file = opts.ssh_identity_file,
        ssh_port          = opts.ssh_port and tostring(opts.ssh_port),
        ssh_username      = opts.ssh_username,
    }):as_list()
    table.insert(cmd, 0, self.config.binary)

    log.fmt_debug('Launch cmd: %s', cmd)
    return auth.spawn({
        cmd = cmd,
        auth = opts.auth,
    }, function(err, connection)
        if err then
            return cb(err)
        end

        -- Update manager to reflect connection
        self.connections[connection] = {
            destination = destination
        }

        return cb(nil, self:client(connection))
    end)
end

--- @class ManagerConnectOpts
--- @field destination string #uri used to identify server's location
---
--- @field auth AuthHandler|nil #authentication handler to use
--- @field config string|nil #alternative config path to use
--- @field cache string|nil #alternative cache path to use
--- @field log_file string|nil #alternative log file path to use
--- @field log_level string|nil #alternative log level to use

--- Connects to a remote server using the given manager
--- @param opts ManagerConnectOpts
--- @param cb fun(err:string|nil, client:Client|nil)
--- @return JobHandle|nil
function Manager:connect(opts, cb)
    opts = opts or {}
    log.fmt_debug('Connecting with options: %s', opts)

    if vim.fn.executable(self.config.binary) ~= 1 then
        log.fmt_error('Executable %s is not on path', self.config.binary)
        return
    end

    local destination = opts.destination
    local cmd = Cmd.client.connect(destination):set_from_tbl({
        -- Explicitly set to use JSON for communication and point to
        -- manager's unix socket or windows pipe
        format       = 'json',
        unix_socket  = self.config.network.unix_socket,
        windows_pipe = self.config.network.windows_pipe,

        -- Optional user settings
        cache     = opts.cache,
        config    = opts.config,
        log_file  = opts.log_file,
        log_level = opts.log_level,
    }):as_list()
    table.insert(cmd, 0, self.config.binary)

    log.fmt_debug('Connect cmd: %s', cmd)
    return auth.spawn({
        cmd = cmd,
        auth = opts.auth,
    }, function(err, connection)
        if err then
            return cb(err)
        end

        -- Update manager to reflect connection
        self.connections[connection] = {
            destination = destination
        }

        return cb(nil, self:client(connection))
    end)
end

return Manager
