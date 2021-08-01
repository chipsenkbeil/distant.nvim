local u = require('distant.utils')

-- Launches a new instance of the distance binary on the remote machine and sets
-- up a session so clients are able to communicate with it
local function launch(host, args)
    assert(type(host) == 'string', 'Missing or invalid host argument')
    args = args or {}

    -- Format is launch {host} [args..]
    local cmd_args = u.build_arg_str(args)
    return u.job_start('distant launch ' .. host .. ' ' .. cmd_args, {
        on_success = function()
            u.log_err('Successfully launched!')
        end;
        on_failure = function(code)
            u.log_err('Launch failed with exit code ' .. code)
        end;
    })
end

return launch
