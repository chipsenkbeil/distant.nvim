local log = require('distant.log')
local settings = require('distant.settings')

return function(opts)
    log.fmt_trace('setup(%s)', opts)
    opts = opts or {}

    -- Update our global settings
    settings.merge(opts)
end
