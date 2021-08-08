local c = require('spec.config')
local editor = require('distant.editor')
local s = require('distant.internal.state')

local utils = {}

-- Prints out the current test configuration
utils.print_config = function()
    print(vim.inspect(c))
end

-- Establishes a new session by launching; this will fail if ssh is not passwordless
utils.setup_session = function(timeout, interval)
    -- Create some additional arguments to pass
    local args = {
        distant = c.bin,
        extra_server_args = '"--current-dir \"' .. c.root_dir .. '\" --shutdown-after 60"',
    }

    editor.launch(c.host, args)
    return utils.wait_for_session(timeout, interval)
end

-- Waits for a session become available
utils.wait_for_session = function(timeout, interval)
    timeout = timeout or c.timeout
    interval = interval or c.timeout_interval

    local status = vim.fn.wait(timeout, function() return s.session() ~= nil end, interval)
    assert(status == 0, 'Session not received in time')
    return s.session()
end

return utils
