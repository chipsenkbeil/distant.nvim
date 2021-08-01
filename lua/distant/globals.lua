local client = require('distant.client')
local c = require('distant.constants')
local u = require('distant.utils')

local globals = {}
local state = {}

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
globals.client = function()
    if not state.client then
        state.client = client:new()
    end

    -- Validate that the version we support is available
    check_version(state.client:version())

    -- If our client died, try to restart it
    if not state.client:is_running() then
        state.client:start({
            verbose = 3;
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
