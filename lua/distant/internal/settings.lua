local c = require('distant.internal.constants')
local u = require('distant.internal.utils')

local log = require('distant.log')

-- Represents the label used to signify default/global settings
local DEFAULT_LABEL = '*'

-- Default settings to apply to any-and-all servers
local DEFAULT_SETTINGS = {
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

        -- Log level (off/error/warn/info/debug/trace) for the client
        log_level = 'warn';
    };

    -- Settings that apply to the client that is created to interact with the server
    client = {
        -- Log file to use with the client
        log_file = nil;

        -- Log level (off/error/warn/info/debug/trace) for the client
        log_level = 'warn';
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

    -- Settings to use to start LSP instances
    lsp = {};
}

local settings = {}

-- Contains the setting definitions for all remote machines, each
-- associated by a label with '*' representing a blanket set of
-- settings to apply first before adding in server-specific settings
local inner = { [DEFAULT_LABEL] = u.merge({}, DEFAULT_SETTINGS) }

--- Merges current settings with provided, overwritting anything with provided
--- @param other table The other settings to include
settings.merge = function(other)
    inner = u.merge(inner, other)
end

--- Returns a collection of labels contained by the settings
--- @param exclude_default? boolean If true, will not include default label in results
--- @return table #A list of labels
settings.labels = function(exclude_default)
    local labels = {}
    for label, _ in pairs(inner) do
        if not exclude_default or label ~= DEFAULT_LABEL then
            table.insert(labels, label)
        end
    end
    return labels
end

--- Retrieve settings for a specific remote machine defined by a label, also
--- applying any default settings
--- @param label string The label associated with the remote server's settings
--- @param no_default? boolean If true, will not apply default settings first
--- @return table #The settings associated with the remote machine (or empty table)
settings.for_label = function(label, no_default)
    log.fmt_trace('settings.for_label(%s, %s)', label, vim.inspect(no_default))

    local specific = inner[label] or {}
    local default = settings.default()

    local settings_for_label = specific
    if not no_default then
        settings_for_label = u.merge(default, specific)
    end

    return settings_for_label
end

--- Retrieves settings that apply to any remote machine
--- @return table #The settings to apply to any remote machine (or empty table)
settings.default = function()
    return inner[DEFAULT_LABEL] or {}
end

return settings
