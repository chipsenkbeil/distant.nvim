local log = require('distant.log')
local settings = require('distant.settings')
local u = require('distant.utils')
local v = require('distant.vars')

local state = {
    -- Set default settings so we don't get nil access errors even when no
    -- launch call has been made yet
    settings = settings.default();

    -- Contains active session
    session = nil;
}

--- Loads into state the settings appropriate for the remote machine with
--- the given label
state.load_settings = function(label)
    state.settings = settings.for_label(label)
end

return state
