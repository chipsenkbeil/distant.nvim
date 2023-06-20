local Error    = require('distant-core.api.error')
local log      = require('distant-core.log')
local utils    = require('distant-core.utils')

local callable = utils.callable

--- @alias distant.core.api.watch.ChangeKind
--- | '"access"' # A file was read
--- | '"attribute"' # A file or directory had its attributes changed
--- | '"close_write"' # A file opened for writing was closed
--- | '"close_no_write"' # A file not opened for writing was closed
--- | '"create"' # A file, directory, or something else was created
--- | '"delete"' # A file or directory was deleted
--- | '"modify"' # The contents of a file were changed
--- | '"open"' # A file was opened
--- | '"rename"' # A file or directory was renamed
--- | '"unknown"' # Catchall in case we have no insight as to the type of change

--- @class distant.core.api.watch.Change
--- @field timestamp integer
--- @field kind distant.core.api.watch.ChangeKind
--- @field path string
--- @field details? distant.core.api.watch.ChangeDetails

--- @class distant.core.api.watch.ChangeDetails
--- @field attribute? 'ownership'|'permissions'|'timestamp'
--- @field renamed? string
--- @field timestamp? integer
--- @field extra? string

-------------------------------------------------------------------------------
-- CLASS DEFINITION
-------------------------------------------------------------------------------

--- Represents a remote file watcher.
--- @class distant.core.api.Watcher
--- @field private __changes distant.core.api.watch.Change[]
--- @field private __on_change? fun(change:distant.core.api.watch.Change)
--- @field private __on_ready? fun(err?:distant.core.api.Error, watcher?:distant.core.api.Watcher)
--- @field private __path string
--- @field private __ready boolean
--- @field private __transport distant.core.api.Transport
local M        = {}
M.__index      = M

--- @param opts {path:string, transport:distant.core.api.Transport}
--- @return distant.core.api.Watcher
function M:new(opts)
    local instance = {}
    setmetatable(instance, M)
    instance.__changes = {}
    instance.__on_change = nil
    instance.__on_ready = nil
    instance.__path = opts.path
    instance.__ready = false
    instance.__transport = opts.transport
    return instance
end

-------------------------------------------------------------------------------
-- GENERAL API
-------------------------------------------------------------------------------

--- Returns the path tied to the watcher.
--- @return string
function M:path()
    return self.__path
end

--- Returns whether or not the watcher is actively watching.
--- @return boolean
function M:is_watching()
    return self.__ready
end

--- Returns changes detected by the watcher. These are only accessible
--- when the watcher does not have a callback configured for changes.
--- @return distant.core.api.watch.Change[]
function M:changes()
    return self.__changes
end

--- Clears changes cached by the watcher. This is only applicable when
--- reading changes without the callback configured.
function M:clear_changes()
    self.__changes = {}
end

--- Sets the callback to use when a change is detected.
--- @param cb fun(change:distant.core.api.watch.Change)
--- @return distant.core.api.Watcher
function M:on_change(cb)
    self.__on_change = cb

    -- If we have any queued changes, we process them now
    local changes = self.__changes
    self.__changes = {}

    if not vim.tbl_isempty(changes) then
        vim.schedule(function()
            local errors = {}
            for _, change in ipairs(changes) do
                local ok, err = pcall(cb, change)
                if not ok then
                    table.insert(errors, tostring(err))
                end
            end
            if not vim.tbl_isempty(errors) then
                error(table.concat(errors, '\n'))
            end
        end)
    end

    return self
end

-------------------------------------------------------------------------------
-- MSG HANDLER
-------------------------------------------------------------------------------

--- Processes the payload of watch events.
--- @package
--- @param payload table
--- @return boolean #true if valid payload, otherwise false
function M:handle(payload)
    -- NOTE: We do the blind assumption that an ok event represents the watch succeeding, nothing more
    if payload.type == 'ok' then
        if not self.__ready then
            self.__ready = true

            local on_ready = self.__on_ready
            if on_ready and callable(on_ready) then
                vim.schedule(function() on_ready(nil, self) end)
            end
        end
        return true
    elseif payload.type == 'changed' then
        local timestamp = assert(
            payload.timestamp,
            'Malformed changed event! Missing timestamp. ' .. vim.inspect(payload)
        )
        local kind = assert(payload.kind, 'Malformed changed event! Missing kind. ' .. vim.inspect(payload))
        local path = assert(payload.path, 'Malformed changed event! Missing path. ' .. vim.inspect(payload))
        local details = payload.details

        --- @type distant.core.api.watch.Change
        local change = { timestamp = timestamp, kind = kind, path = path, details = details }

        -- If we have an on_change callback, pass directly to it;
        -- otherwise, queue up the change in our changes list
        local on_change = self.__on_change
        if self.__ready and on_change and callable(on_change) then
            vim.schedule(function() on_change(change) end)
        else
            table.insert(self.__changes, change)
        end

        return true
    else
        log.fmt_warn('Watcher received unexpected payload: %s', payload)
        return false
    end
end

-------------------------------------------------------------------------------
-- WATCH API
-------------------------------------------------------------------------------

--- @class distant.core.api.watcher.WatchOpts
--- @field path string
--- @field recursive? boolean
--- @field only? distant.core.api.watch.ChangeKind[]
--- @field except? distant.core.api.watch.ChangeKind[]
--- @field timeout? number
--- @field interval? number

--- Watches the specified path.
---
--- If a callback is provided, it will return the watcher once watching has begun;
--- otherwise, the function will wait for the watcher to be ready and then return it.
---
--- ### Options
---
--- * `recursive` indicates that paths nested within the provided path will also be watched.
--- * `only` can be provided to restrict received change events to only those specified.
--- * `except` can be provided to restrict received change events to all except those specified.
---
--- @param opts distant.core.api.watcher.WatchOpts
--- @param cb? fun(err?:distant.core.api.Error, watcher?:distant.core.api.Watcher)
--- @return distant.core.api.Error|nil,distant.core.api.Watcher|nil
function M:watch(opts, cb)
    local timeout = opts.timeout or self.__transport.config.timeout
    local interval = opts.interval or self.__transport.config.interval

    -- If no callback provided, we create a synchronous channel
    local rx
    if not cb or not callable(cb) then
        cb, rx = utils.oneshot_channel(timeout, interval)
    end

    -- Set our ready callback
    self.__on_ready = cb

    self.__transport:send_async({
        payload = {
            type = 'watch',
            path = opts.path,
            recursive = opts.recursive,
            only = opts.only,
            except = opts.except,
        },
        more = function(payload)
            local ty = payload.type
            return ty == 'ok' or ty == 'changed'
        end,
    }, function(payload)
        -- Specially handle error type if we get it when trying to watch
        if type(payload) == 'table' and payload.type == 'error' then
            -- If not ready and the payload failed, then this is the response to our initial request
            if not self.__ready then
                self.__ready = true

                vim.schedule(function()
                    cb(Error:new({
                        kind = payload.kind or Error.kinds.unknown,
                        description = payload.description or '???',
                    }), nil)
                end)
                return
            end
        end

        if not self:handle(payload) then
            -- If not ready and the payload failed, then this is the response to our initial request
            if not self.__ready then
                self.__ready = true

                vim.schedule(function()
                    cb(Error:new({
                        kind = Error.kinds.invalid_data,
                        description = 'Invalid response payload: ' .. vim.inspect(payload),
                    }), nil)
                end)
            end
        end
    end)

    -- Running synchronously, so return the watcher
    if rx then
        --- @type boolean, distant.core.api.Error|nil, distant.core.api.Watcher|nil
        local status, err, watcher = pcall(rx)

        if not status then
            return Error:new({
                kind = Error.kinds.timed_out,
                description = tostring(err),
            })
        else
            return err, watcher
        end
    end
end

-------------------------------------------------------------------------------
-- UNWATCH API
-------------------------------------------------------------------------------

--- Unwatches the path. Takes optional `opts` to specify how long to wait when synchronous.
---
--- If provided a `cb` function, will return asynchronously.
---
--- @param opts? {timeout?:number, interval?:number}
--- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.OkPayload)
--- @return distant.core.api.Error|nil, distant.core.api.OkPayload|nil
function M:unwatch(opts, cb)
    opts = opts or {}

    -- If callback given as first argument, switch it up
    if not cb and callable(opts) then
        --- @diagnostic disable-next-line:cast-type-mismatch
        --- @cast opts fun(err?:distant.core.api.Error, payload?:distant.core.api.OkPayload)
        cb = opts
        opts = {}
    end

    local timeout = opts.timeout or self.__transport.config.timeout
    local interval = opts.interval or self.__transport.config.interval
    return self.__transport:send({
        payload = {
            type = 'unwatch',
            path = self.__path,
        },
        verify = function(payload)
            return payload.type == 'ok'
        end,
        timeout = timeout,
        interval = interval,
    }, cb)
end

return M
