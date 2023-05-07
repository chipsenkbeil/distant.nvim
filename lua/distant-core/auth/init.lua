local AuthHandler = require('distant-core.auth.handler')
local spawn = require('distant-core.auth.spawn')

return {
    --- Create a new handler for authentication events.
    --- @return distant.auth.Handler
    handler = function() return AuthHandler:new() end,
    spawn = spawn,
}
