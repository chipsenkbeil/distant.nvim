local Error = require('distant-core.client.api.error')
local log   = require('distant-core.log')
local utils = require('distant-core.utils')

--- Represents an active search.
--- @class distant.client.api.Searcher
--- @field private __internal distant.client.api.search.Internal
local M     = {}
M.__index   = M

--- @class distant.client.api.search.Internal
--- @field id? integer #unsigned 32-bit id, assigned once the search starts
--- @field on_done? fun(matches:distant.client.api.search.Match[])
--- @field on_results? fun(matches:distant.client.api.search.Match[])
--- @field on_start? fun(id:integer)
--- @field matches distant.client.api.search.Match[] #will be populated if `on_results`, `on_start`, `on_done` are nil
--- @field transport distant.api.client.Transport
--- @field status 'inactive'|'active'|'done'
--- @field timeout? number
--- @field interval? number

--- @class distant.client.api.search.Match
--- @field type 'contents'|'path'
--- @field path string
--- @field submatches distant.client.api.search.Submatch[]
--- @field lines? distant.client.api.search.MatchData #only provided when type == 'path'
--- @field line_number? integer #(base index 1) only provided when type == 'path'
--- @field absolute_offset? integer #(base index 0) only provided when type == 'path'

--- @class distant.client.api.search.Submatch
--- @field match distant.client.api.search.MatchData
--- @field start integer #(base index 0) inclusive byte offset representing start of match
--- @field end integer #(base index 0) inclusive byte offset representing end of match

--- @alias distant.client.api.search.MatchData {type:'bytes', value:integer[]}|{type:'text', value:string}

--- @class distant.client.api.search.Query
--- @field target 'contents'|'path'
--- @field condition distant.client.api.search.QueryCondition
--- @field paths string[]
--- @field options? distant.client.api.search.QueryOptions

--- @class distant.client.api.search.QueryCondition
--- @field type 'contains'|'ends_with'|'equals'|'or'|'regex'|'starts_with'
--- @field value string|distant.client.api.search.QueryCondition[]

--- @class distant.client.api.search.QueryOptions
--- @field allow_file_types? 'dir'|'file'|'symlink'[]
--- @field include? distant.client.api.search.QueryCondition
--- @field exclude? distant.client.api.search.QueryCondition
--- @field follow_symbolic_links? boolean
--- @field limit? integer
--- @field max_depth? integer
--- @field pagination? integer

--- @param opts {transport:distant.api.client.Transport}
--- @return distant.client.api.Searcher
function M:new(opts)
    local instance = {}
    setmetatable(instance, M)
    instance.__internal = {
        matches = {},
        transport = opts.transport,
        status = 'inactive',
    }

    return instance
end

--- Processes the payload of a search event.
--- @param payload {type:string, id:integer, matches?:distant.client.api.search.Match[]}
--- @return boolean #true if valid payload, otherwise false
function M:handle(payload)
    if payload.type == 'search_started' then
        local id = assert(tonumber(payload.id), 'Malformed search started event! Missing id. ' .. vim.inspect(payload))
        if self:id() then
            log.fmt_warn('Received a "search_started" event with id %s, but already started with id %s', id, self:id())
        end
        self.__internal.id = id
        self.__internal.status = 'active'

        if type(self.__internal.on_start) == 'function' then
            self.__internal.on_start(id)
        end
        return true
    elseif payload.type == 'search_done' then
        local id = assert(tonumber(payload.id), 'Malformed search done event! Missing id. ' .. vim.inspect(payload))
        if self:id() ~= id then
            log.fmt_warn('Received a "search_done" event with id %s that does not match %s', id, self:id())
        end
        self.__internal.status = 'done'

        if type(self.__internal.on_done) == 'function' then
            self.__internal.on_done(self.__internal.matches)
            self.__internal.matches = {}
        end
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

        if type(self.__internal.on_results) == 'function' then
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
--- @field query distant.client.api.search.Query
--- @field on_results? fun(matches:distant.client.api.search.Match[])
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
--- @param cb? fun(err?:distant.api.Error, matches?:distant.client.api.search.Match[])
--- @return distant.api.Error|nil, distant.client.api.search.Match[]|nil
function M:execute(opts, cb)
    local tx, rx = utils.oneshot_channel(
        opts.timeout or self.__internal.transport.config.timeout,
        opts.interval or self.__internal.transport.config.interval
    )

    self.__internal.on_done = function(matches)
        if not vim.tbl_isempty(matches) then
            for _, match in ipairs(matches) do
                table.insert(self.__internal.matches, match)
            end
        end

        if type(cb) == 'function' then
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
            if type(cb) == 'function' then
                cb('Invalid response payload: ' .. vim.inspect(payload), nil)
            else
                tx({ err = 'Invalid response payload: ' .. vim.inspect(payload) })
            end
        end
    end)

    -- Running synchronously, so pull in our results
    if not cb then
        --- @type boolean, string|{err:string}|{matches:distant.client.api.search.Match[]}
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
--- @param cb? fun(err?:distant.api.Error, payload?:distant.client.api.OkPayload)
--- @return distant.api.Error|nil, distant.client.api.OkPayload|nil
function M:cancel(cb)
    return self.__internal.transport:send({
        payload = {
            type = 'cancel_search',
            id = self:id(),
        },
        cb = cb,
        verify = function(payload)
            return payload.type == 'ok'
        end,
        timeout = self.__internal.timeout,
        interval = self.__internal.interval,
    })
end

return M
