local c = require('distant.internal.constants')
local s = require('distant.internal.settings')
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

--- Loads into state the settings appropriate for the remote machine with
--- the given label
state.load_settings = function(label)
    state.settings = s.for_label(label)
end

-- Set default settings so we don't get nil access errors even when no launch
-- call has been made yet
state.settings = s.default()

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
