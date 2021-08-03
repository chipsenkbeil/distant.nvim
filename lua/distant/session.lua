local g = require('distant.internal.globals')

local session = {}

--- Clears the session
session.clear = function()
    g.set_session(nil)
end

--- Check if a session exists
---
--- @return true if exists, otherwise false
session.exists = function()
    return g.session() ~= nil
end

--- Retrieve session information
---
--- @return {'host' = ...; 'port' = ...} if available, otherwise nil
session.info = function()
    return g.session()
end

return session
