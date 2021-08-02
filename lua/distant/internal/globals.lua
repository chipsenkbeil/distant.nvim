local c = require('distant.internal.constants')
local u = require('distant.internal.utils')

local globals = {}
local state = {
    client = nil;
    callbacks = {};
}

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

--- Sets a callback to be stored globally, returning an id for future reference
---
--- @param cb function The callback to store
--- @return string id A unique id associated with the callback
globals.set_callback = function(cb)
    local id = 'cb_' .. u.next_id()
    state.callbacks[id] = cb
    return id
end

--- Removes the callback with the specified id
---
--- @param id string The id associated with the callback
globals.del_callback = function(id)
    state.callbacks[id] = nil
end

--- Retrieves a callback by its id
---
--- @param id string The id associated with the callback
--- @return function|nil #The callback function if found
globals.callback = function(id)
    return state.callbacks[id]
end

--- Retrieves the client, optionally initializing it if needed
globals.client = function()
    -- NOTE: Inlined here to avoid loop from circular dependencies
    local client = require('distant.internal.client')
    if not state.client then
        state.client = client:new()

        -- Define augroup that will stop client when exiting neovim
        u.augroup('distant_client', function()
            u.autocmd('VimLeave', '*', function()
                -- TODO: This is not working right now
                state.client:stop()
            end)
        end)
    end

    -- Validate that the version we support is available
    check_version(state.client:version())

    -- If our client died, try to restart it
    if not state.client:is_running() then
        state.client:start(u.merge(globals.settings.client, {
            on_exit = function(code)
                if code ~= 0 then
                    u.log_err('client failed to start! Error code ' .. code)
                end
            end;
        }))
    end

    return state.client
end

--- Settings for use around the plugin
globals.settings = {
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

    -- All of these settings are for starting a client
    client = {
        log_file = nil;
        verbose = 0;
    };
}

return globals
