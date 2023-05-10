local EventEmitter = require('distant-core').EventEmitter

--- @class distant.EventEmitter
--- @field private __emitter distant.core.EventEmitter
local M = {}
M.__index = M

--- Internal event emitter that maintains our state across the plugin.
M.__emitter = EventEmitter:new()

--- @alias distant.events.Event
--- | '"connection:changed"' # when the plugin switches the active connection
--- | '"manager:started"' # when the manager was not running and was started by the plugin
--- | '"manager:loaded"' # when the manager is loaded for the first time
--- | '"settings:changed"' # when the stateful settings are changed

-------------------------------------------------------------------------------
-- GENERAL API
-------------------------------------------------------------------------------

--- Emits the specified event to trigger all associated handlers
--- and passes all additional arguments to the handler.
---
--- @param event distant.events.Event # event to emit
--- @param ... any # additional arguments to get passed to handlers
--- @return distant.EventEmitter
function M.emit(event, ...)
    M.__emitter:emit(event, ...)
    return M
end

--- Registers a callback to be invoked when the specified event is emitted.
--- More than one handler can be associated with the same event.
---
--- @param event distant.events.Event # event to receive
--- @param handler fun(payload:any) # callback to trigger on event
--- @return distant.EventEmitter
function M.on(event, handler)
    M.__emitter:on(event, handler)
    return M
end

--- Registers a callback to be invoked when the specified event is emitted.
--- Upon being triggered, the handler will be removed.
---
--- More than one handler can be associated with the same event.
---
--- @param event distant.events.Event # event to receive
--- @param handler fun(payload:any) # callback to trigger on event
--- @return distant.EventEmitter
function M.once(event, handler)
    M.__emitter:once(event, handler)
    return M
end

--- Unregisters the callback for the specified event.
---
--- @param event distant.events.Event # event whose handler to remove
--- @param handler fun(payload:any) # handler to remove
--- @return distant.EventEmitter
function M.off(event, handler)
    M.__emitter:off(event, handler)
    return M
end

-------------------------------------------------------------------------------
-- EVENT-SPECIFIC API
-------------------------------------------------------------------------------

--- @param connection distant.core.Client
function M.emit_connection_changed(connection)
    M.emit('connection:changed', connection)
end

--- @param handler fun(connection:distant.core.Client)
function M.on_connection_changed(handler)
    M.on('connection:changed', handler)
end

--- @param manager distant.core.Manager
function M.emit_manager_started(manager)
    M.emit('manager:started', manager)
end

--- @param handler fun(manager:distant.core.Manager)
function M.on_manager_started(handler)
    M.on('manager:started', handler)
end

--- @param manager distant.core.Manager
function M.emit_manager_loaded(manager)
    M.emit('manager:loaded', manager)
end

--- @param handler fun(manager:distant.core.Manager)
function M.on_manager_loaded(handler)
    M.on('manager:loaded', handler)
end

--- @param settings distant.core.Settings
function M.emit_settings_changed(settings)
    M.emit('settings:changed', settings)
end

--- @param handler fun(settings:distant.core.Settings)
function M.on_settings_changed(handler)
    M.on('settings:changed', handler)
end

return M
