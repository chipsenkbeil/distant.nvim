local log      = require('distant-core').log
local settings = require('distant-core').settings

return function(opts)
    log.fmt_trace('setup(%s)', opts)
    opts = opts or {}

    -- Update our global settings
    settings.merge(opts)
end
