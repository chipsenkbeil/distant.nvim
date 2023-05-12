local EventEmitter = require('distant-core').EventEmitter

--- Specialized event emitter that works with distant-specific events.
--- @type distant.events.Emitter
--- @diagnostic disable-next-line:assign-type-mismatch
local EVENT_EMITTER = EventEmitter:new()
return EVENT_EMITTER
