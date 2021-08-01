local settings = require('distant.settings')

return function(opts)
    opts = opts or {}

    -- Override global settings with options
    for k, v in pairs(opts) do
        settings[k] = v
    end
end
