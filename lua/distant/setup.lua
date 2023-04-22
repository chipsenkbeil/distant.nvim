local core = require('distant-core')
local log = core.log
local settings = core.settings

return function(opts)
    log.fmt_trace('setup(%s)', opts)
    opts = opts or {}

    -- Update our global settings
    settings.merge(opts)
end
