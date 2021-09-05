local settings = require('distant.internal.settings')

return function(opts)
    opts = opts or {}

    -- Update our global settings
    settings.merge(opts)
end
