local c = require('distant.internal.constants')
local u = require('distant.internal.utils')

local state = {}

-- Inner data that is not directly exposed
local inner = {
    client = nil;
    data = {};
    session = nil;
}

-------------------------------------------------------------------------------
-- SETTINGS DEFINITION & OPERATIONS
-------------------------------------------------------------------------------

--- Settings for use around the plugin
state.settings = {
    -- Path to the local `distant` binary
    binary_name = c.BINARY_NAME;

    -- Maximum time (in milliseconds) to wait for a request to complete
    max_timeout = c.MAX_TIMEOUT;

    -- Time (in milliseconds) between checks for the timeout to be reached
    timeout_interval = c.TIMEOUT_INTERVAL;

    -- Settings that apply when launching the server
    launch = {
        -- Control the IP address that the server will bind to
        bind_server = nil;

        -- Alternative location for the distant binary on the remote machine
        distant = nil;

        -- Additional arguments to the server when launched (see listen help)
        extra_server_args = nil;

        -- Identity file to use with ssh
        identity_file = nil;

        -- Log file to use when running the launch command
        log_file = nil;

        -- Alternative port to port 22 for use in SSH
        port = nil;

        -- Maximum time (in seconds) for the server to run with no active connections
        shutdown_after = nil;

        -- Alternative location for the ssh binary on the local machine
        ssh = nil;

        -- Username to use when logging into the remote machine via SSH
        username = nil;

        -- Verbosity level (1 = info, 2 = debug, 3 = trace) for the launch command
        verbose = 0;
    };

    -- Settings that apply to the client that is created to interact with the server
    client = {
        -- Log file to use with the client
        log_file = nil;

        -- Verbosity level (1 = info, 2 = debug, 3 = trace) for the client
        verbose = 0;
    };

    -- Settings that apply when editing a remote file
    file = {
        -- Mappings to apply to remote files
        mappings = {};
    };

    -- Settings that apply to the navigation interface
    dir = {
        -- Mappings to apply to the navigation interface
        mappings = {};
    };
}

--- Retrieve settings for a specific remote machine defined by a label, also
--- applying any default settings
--- @param label string The label associated with the remote server's settings
--- @return table #The settings associated with the remote machine (or empty table)
state.settings_by_label = function(label)
    local specific = state.settings.server[label] or {}
    local default = state.settings.server['*'] or {}
    return u.merge(default, specific)
end

-------------------------------------------------------------------------------
-- DATA OPERATIONS
-------------------------------------------------------------------------------

--- Contains operations to apply against a global collection of functions
state.data = {}

--- Inserts data into the global storage, returning an id for future reference
---
--- @param data any The data to store
--- @param prefix? string Optional prefix to add to the id created for the data
--- @return string #A unique id associated with the data
state.data.insert = function(data, prefix)
    prefix = prefix or 'data_'
    local id = prefix .. u.next_id()
    inner.data[id] = data
    return id
end

--- Removes the data with the specified id
---
--- @param id string The id associated with the data
--- @return any? #The removed data, if any
state.data.remove = function(id)
    return state.data.set(id, nil)
end

--- Updates data by its id
---
--- @param id string The id associated with the data
--- @param value any The new value for the data
--- @return any? #The old value of the data, if any
state.data.set = function(id, value)
    local data = inner.data[id]
    inner.data[id] = value
    return data
end

--- Retrieves data by its id
---
--- @param id string The id associated with the data
--- @return any? #The data if found
state.data.get = function(id)
    return inner.data[id]
end

--- Checks whether data with the given id exists
---
--- @param id string The id associated with the data
--- @return boolean #True if it exists, otherwise false
state.data.has = function(id)
    return inner.data[id] ~= nil
end

--- Retrieves a key mapping around some data by the data's id,
--- assuming that the data will be a function that can be invoked
---
--- @param id number The id associated with the data
--- @param args? string[] #Arguments to feed directly to the data as a function
--- @return string #The mapping that would invoke the data with the given id
state.data.get_as_key_mapping = function(id, args)
    args = table.concat(args or {}, ',')
    return 'lua require("distant.internal.state").data.get("' .. id .. '")(' .. args .. ')'
end

-------------------------------------------------------------------------------
-- CLIENT OPERATIONS
-------------------------------------------------------------------------------

local function check_version(version)
    local min = c.MIN_SUPPORTED_VERSION
    local fail_msg = (
        table.concat(version, '.') ..
        ' is lower than minimum version ' ..
        table.concat(min, '.')
    )

    local v_num = tonumber(version[1] .. version[2] .. version[3])
    local m_num = tonumber(min[1] .. min[2] .. min[3])

    assert(v_num >= m_num, fail_msg)
end

--- Retrieves the client, optionally initializing it if needed
state.client = function()
    -- NOTE: Inlined here to avoid loop from circular dependencies
    local client = require('distant.internal.client')
    if not inner.client then
        inner.client = client:new()

        -- Define augroup that will stop client when exiting neovim
        u.augroup('distant_client', function()
            u.autocmd('VimLeave', '*', function()
                if inner.client then
                    inner.client:stop()
                end
            end)
        end)
    end

    -- Validate that the version we support is available
    check_version(inner.client:version())

    -- If our client died, try to restart it
    if not inner.client:is_running() then
        inner.client:start(u.merge(state.settings.client, {
            on_exit = function(code)
                if code ~= 0 and inner.client:is_running() then
                    u.log_err('client failed to start! Error code ' .. code)
                end
            end;
        }))
    end

    return inner.client
end

-------------------------------------------------------------------------------
-- SESSION OPERATIONS
-------------------------------------------------------------------------------

--- Sets the globally-available session
--- @param session table|nil the session in the form of {host, port, auth key}
state.set_session = function(session)
    inner.session = session
end

--- Returns the current session, or nil if unavailable
--- @return table|nil #the session in the form of {host, port, auth key}
state.session = function()
    return inner.session
end

return state
