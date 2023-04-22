local core = require('distant-core')
local state = core.state

--- @param obj table<string, function>
--- @param names string[]
--- @return table<string, function>
local function make_fns(obj, names)
    for _, name in ipairs(names) do
        obj[name] = function(...)
            local client = assert(
                state.client,
                'Client must be initialized before invoking fn'
            )
            return client:api()[name](...)
        end
    end

    -- Add our custom, hard-coded methods as well
    obj.cached_system_info = function()
        local client = assert(
            state.client,
            'Client must be initialized before invoking fn'
        )
        return client:system_info()
    end

    return obj
end

-------------------------------------------------------------------------------
-- FUNCTION API
-------------------------------------------------------------------------------

return make_fns({}, {
    'append_file',
    'append_file_text',
    'capabilities',
    'copy',
    'create_dir',
    'exists',
    'metadata',
    'read_dir',
    'read_file',
    'read_file_text',
    'remove',
    'rename',
    'search',
    'spawn',
    'spawn_wait',
    'system_info',
    'watch',
    'write_file',
    'write_file_text',
})
