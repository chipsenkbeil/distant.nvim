local Error    = require('distant-core.api.error')
local log      = require('distant-core.log')
local utils    = require('distant-core.utils')

local callable = utils.callable

--- Represents an active search.
--- @class distant.core.api.Searcher
--- @field private __internal distant.core.api.search.Internal
local M        = {}
M.__index      = M

--- @class distant.core.api.search.Internal
--- @field id? integer #unsigned 32-bit id, assigned once the search starts
--- @field on_done fun(matches:distant.core.api.search.Match[])
--- @field on_results? fun(matches:distant.core.api.search.Match[])
--- @field on_start? fun(id:integer)
--- @field matches distant.core.api.search.Match[] #will be populated if `on_results`, `on_start`, `on_done` are nil
--- @field transport distant.core.api.Transport
--- @field status 'inactive'|'active'|'done'
--- @field timeout? number
--- @field interval? number

--- @class distant.core.api.search.Match
--- @field type 'contents'|'path'
--- @field path string
--- @field submatches distant.core.api.search.Submatch[]
--- @field lines? distant.core.api.search.MatchData #only provided when type == 'path'
--- @field line_number? integer #(base index 1) only provided when type == 'path'
--- @field absolute_offset? integer #(base index 0) only provided when type == 'path'

--- @class distant.core.api.search.Submatch
--- @field match distant.core.api.search.MatchData
--- @field start integer #(base index 0) inclusive byte offset representing start of match
--- @field end integer #(base index 0) inclusive byte offset representing end of match

--- @alias distant.core.api.search.MatchData integer[]|string

--- @class distant.core.api.search.Query
--- @field target 'contents'|'path'
--- @field condition distant.core.api.search.QueryCondition
--- @field paths string[]
--- @field options? distant.core.api.search.QueryOptions

--- @class distant.core.api.search.QueryCondition
--- @field type 'contains'|'ends_with'|'equals'|'or'|'regex'|'starts_with'
--- @field value string|distant.core.api.search.QueryCondition[]

--- @class distant.core.api.search.QueryOptions
--- @field allow_file_types? ('dir'|'file'|'symlink')[]
--- @field include? distant.core.api.search.QueryCondition
--- @field exclude? distant.core.api.search.QueryCondition
--- @field follow_symbolic_links? boolean
--- @field ignore_hidden? boolean
--- @field limit? integer
--- @field max_depth? integer
--- @field pagination? integer
--- @field upward? boolean
--- @field use_git_exclude_files? boolean
--- @field use_git_ignore_files? boolean
--- @field use_global_git_ignore_files? boolean
--- @field use_ignore_files? boolean
--- @field use_parent_ignore_files? boolean

--- @param opts {transport:distant.core.api.Transport}
--- @return distant.core.api.Searcher
function M:new(opts)
    local instance = {}
    setmetatable(instance, M)
    instance.__internal = {
        matches = {},
        transport = opts.transport,
        status = 'inactive',
        on_done = function(_)
        end,
    }

    return instance
end

--- Processes the payload of a search event.
--- @param payload {type:string, id:integer, matches?:distant.core.api.search.Match[]}
--- @return boolean #true if valid payload, otherwise false
function M:handle(payload)
    if payload.type == 'search_started' then
        local id = assert(tonumber(payload.id), 'Malformed search started event! Missing id. ' .. vim.inspect(payload))
        if self:id() then
            log.fmt_warn('Received a "search_started" event with id %s, but already started with id %s', id, self:id())
        end
        self.__internal.id = id
        self.__internal.status = 'active'

        if self.__internal.on_start and utils.callable(self.__internal.on_start) then
            self.__internal.on_start(id)
        end
        return true
    elseif payload.type == 'search_done' then
        local id = assert(tonumber(payload.id), 'Malformed search done event! Missing id. ' .. vim.inspect(payload))
        if self:id() ~= id then
            log.fmt_warn('Received a "search_done" event with id %s that does not match %s', id, self:id())
        end
        self.__internal.status = 'done'

        local matches = self.__internal.matches
        self.__internal.matches = {}

        self.__internal.on_done(matches)
        return true
    elseif payload.type == 'search_results' then
        local id = assert(tonumber(payload.id), 'Malformed search started event! Missing id. ' .. vim.inspect(payload))
        local matches = assert(
            payload.matches,
            'Malformed search results event! Missing matches. ' .. vim.inspect(payload)
        )
        if self:id() ~= id then
            log.fmt_warn('Received a "search_results" event with id %s that does not match %s', id, self:id())
        end

        if self.__internal.on_results and utils.callable(self.__internal.on_results) then
            self.__internal.on_results(matches)
        else
            for _, m in ipairs(matches) do
                table.insert(self.__internal.matches, m)
            end
        end
        return true
    else
        log.fmt_warn('Search received unexpected payload: %s', payload)
        return false
    end
end

--- Returns the id of the search, if it has started.
--- @return number|nil
function M:id()
    return self.__internal.id
end

--- Returns the status of the search.
--- @return 'inactive'|'active'|'done'
function M:status()
    return self.__internal.status
end

--- Returns whether or not the search is finished.
--- @return boolean
function M:is_done()
    return self:status() == 'done'
end

--- @class DistantApiSearcherExecuteOpts
--- @field query distant.core.api.search.Query
--- @field on_results? fun(matches:distant.core.api.search.Match[])
--- @field on_start? fun(id:integer)
--- @field timeout? number
--- @field interval? number

--- Starts the search. If a callback is provided, matches will be returned asynchronously,
--- otherwise they will be returned synchronously.
---
--- Alternatively, an `on_results` function can be provided to receive results asynchronously
--- as they are received.
---
--- @param opts DistantApiSearcherExecuteOpts
--- @param cb? fun(err?:distant.core.api.Error, matches?:distant.core.api.search.Match[])
--- @return distant.core.api.Error|nil err, distant.core.api.search.Match[]|nil matches
function M:execute(opts, cb)
    local tx, rx = utils.oneshot_channel(
        opts.timeout or self.__internal.transport.config.timeout,
        opts.interval or self.__internal.transport.config.interval
    )

    -- We always handle the done state of a search by either leveraging
    -- the provided callback or feeding the results back through the channel
    self.__internal.on_done = function(matches)
        if not vim.tbl_isempty(matches) then
            for _, match in ipairs(matches) do
                table.insert(self.__internal.matches, match)
            end
        end

        if cb and utils.callable(cb) then
            cb(nil, self.__internal.matches)
        else
            tx({ matches = self.__internal.matches })
        end
    end

    self.__internal.on_results = opts.on_results
    self.__internal.on_start = opts.on_start
    self.__internal.timeout = opts.timeout
    self.__internal.interval = opts.timeout

    self.__internal.transport:send_async({
        payload = {
            type = 'search',
            query = opts.query,
        },
        more = function(payload)
            local ty = payload.type

            -- NOTE: We do NOT include search_done because we want the callback
            --       to terminate once the done payload is received!
            return ty == 'search_started' or ty == 'search_results'
        end,
    }, function(payload)
        if not self:handle(payload) then
            if cb and callable(cb) then
                cb(Error:new({
                    kind = Error.kinds.invalid_data,
                    description = 'Invalid response payload: ' .. vim.inspect(payload)
                }), nil)
            else
                tx({ err = 'Invalid response payload: ' .. vim.inspect(payload) })
            end
        end
    end)

    -- Running synchronously, so pull in our results
    if not cb then
        --- @type boolean, string|{err:string}|{matches:distant.core.api.search.Match[]}
        local status, results = pcall(rx)

        if not status then
            return Error:new({
                kind = Error.kinds.timed_out,
                --- @cast results string
                description = results,
            })
        elseif results.err then
            return Error:new({
                kind = Error.kinds.invalid_data,
                description = results.err,
            })
        elseif results.matches then
            return nil, results.matches
        end
    end
end

--- Cancels the search if running asynchronously.
--- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.OkPayload)
--- @return distant.core.api.Error|nil err, distant.core.api.OkPayload|nil payload
function M:cancel(cb)
    return self.__internal.transport:send({
        payload = {
            type = 'cancel_search',
            id = self:id(),
        },
        verify = function(payload)
            return payload.type == 'ok'
        end,
        timeout = self.__internal.timeout,
        interval = self.__internal.interval,
    }, cb)
end

return M
