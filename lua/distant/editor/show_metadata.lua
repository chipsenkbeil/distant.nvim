local log    = require('distant-core').log
local plugin = require('distant')
local window = require('distant.ui.windows.metadata')

-------------------------------------------------------------------------------
-- OPEN WINDOW
-------------------------------------------------------------------------------

--- Opens a new window to show metadata for some path.
--- @param opts distant.core.api.MetadataOpts
return function(opts)
    opts = opts or {}
    log.fmt_trace('editor.show_metadata(%s)', opts)
    local path = opts.path
    if not path then
        error('opts.path is missing')
    end

    window:open()

    --- @param state distant.plugin.ui.windows.metadata.State
    window:mutate_state(function(state)
        state.path = opts.path
    end)

    -- Retrieve metadata using the active client
    local err, metadata = plugin.api.metadata(opts)

    if err then
        window:close()
    end

    assert(not err, tostring(err))
    assert(metadata)

    --- @param state distant.plugin.ui.windows.metadata.State
    window:mutate_state(function(state)
        state.path = opts.path
        state.metadata = metadata
    end)
end
