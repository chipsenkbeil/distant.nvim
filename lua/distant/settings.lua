local c = require('distant.constants')

local settings = {
    binary_name = c.BINARY_NAME;
    max_timeout = c.MAX_TIMEOUT;
    timeout_interval = c.TIMEOUT_INTERVAL;

    -- All of these launch settings are unset by default
    launch = {
        bind_server = nil;
        extra_server_args = nil;
        identity_file = nil;
        log_file = nil;
        port = nil;
        remote_program = nil;
        ssh_program = nil;
        username = nil;
    };
}

return settings
