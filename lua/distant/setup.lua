local g = require('distant.globals')
local u = require('distant.utils')

return function(opts)
    opts = opts or {}
    g.settings = u.merge(g.settings, opts)
end
