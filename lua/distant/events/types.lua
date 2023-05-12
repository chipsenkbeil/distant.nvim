--- @meta

--- @alias distant.events.Event
--- | '"connection:changed"' # when the plugin switches the active connection
--- | '"manager:started"' # when the manager was not running and was started by the plugin
--- | '"manager:loaded"' # when the manager is loaded for the first time
--- | '"settings:changed"' # when the stateful settings are changed
--- | '"setup:finished"' # when setup of the plugin has finished

--- @class distant.events.Emitter
local M = {}

--- Emits the specified event to trigger all associated handlers
--- and passes all additional arguments to the handler.
---
--- @param event distant.events.Event # event to emit
--- @param ... any # additional arguments to get passed to handlers
--- @return distant.events.Emitter
function M:emit(event, ...)
end

--- Registers a callback to be invoked when the specified event is emitted.
--- More than one handler can be associated with the same event.
---
--- @param event distant.events.Event # event to receive
--- @param handler fun(payload:any) # callback to trigger on event
--- @return distant.events.Emitter
function M:on(event, handler)
end

--- Registers a callback to be invoked when the specified event is emitted.
--- Upon being triggered, the handler will be removed.
---
--- More than one handler can be associated with the same event.
---
--- @param event distant.events.Event # event to receive
--- @param handler fun(payload:any) # callback to trigger on event
--- @return distant.events.Emitter
function M:once(event, handler)
end

--- Unregisters the callback for the specified event.
---
--- @param event distant.events.Event # event whose handler to remove
--- @param handler fun(payload:any) # handler to remove
--- @return distant.events.Emitter
function M:off(event, handler)
end
