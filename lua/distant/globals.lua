local client = require('distant.client')
local u = require('distant.utils')

local globals = {}
local state = {}


-- Retrieves the client, optionally initializing it if needed
globals.client = function()
    if not state.client then
        state.client = client:new()
    end

    -- If our client died, try to restart it
    if not state.client:is_running() then
        state.client:start({
            verbose = true;
            log_file = "/tmp/client.log";
            on_exit = function(code)
                if code ~= 0 then
                    u.log_err('client failed to start! Error code ' .. code)
                end
            end;
        })
    end

    return state.client
end

return globals
