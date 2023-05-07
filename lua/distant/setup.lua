local log      = require('distant-core').log
local settings = require('distant-core').settings

--- Applies provided settings to overall settings available.
--- @param opts table<string, distant.core.Settings>
return function(opts)
    log.fmt_trace('setup(%s)', opts)
    opts = opts or {}

    -- Update our global settings
    settings.merge(opts)
end
