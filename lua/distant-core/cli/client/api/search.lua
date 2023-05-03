local log   = require('distant-core.log')
local utils = require('distant-core.utils')

--- Represents an active search.
--- @class DistantApiSearch
--- @field __internal DistantApiSearchInternal
local M     = {}
M.__index   = M

--- @class DistantApiSearchInternal
--- @field id? integer #unsigned 32-bit id, assigned once the search starts
--- @field on_done? fun(matches:DistantApiSearchMatch[])
--- @field on_results? fun(matches:DistantApiSearchMatch[])
--- @field matches DistantApiSearchMatch[] #will be populated if `on_results` and `on_done` are nil
--- @field transport DistantApiTransport
--- @field status 'inactive'|'active'|'done'
--- @field timeout? number
--- @field interval? number

--- @class DistantApiSearchMatch
--- @field type 'contents'|'path'
--- @field path string
--- @field submatches DistantApiSearchSubmatch[]
--- @field lines? DistantApiSearchMatchData #only provided when type == 'path'
--- @field line_number? integer #(base index 1) only provided when type == 'path'
--- @field absolute_offset? integer #(base index 0) only provided when type == 'path'

--- @class DistantApiSearchSubmatch
--- @field match DistantApiSearchMatchData
--- @field start integer #(base index 0) inclusive byte offset representing start of match
--- @field end integer #(base index 0) inclusive byte offset representing end of match

--- @class DistantApiSearchMatchData
--- @field type 'bytes'|'text'
--- @field value integer[]|string #if type is bytes, will be a list of bytes, otherwise type is text, will be string

--- @class DistantApiSearchQuery
--- @field target 'contents'|'path'
--- @field condition DistantApiSearchQueryCondition
--- @field paths string[]
--- @field options? DistantApiSearchQueryOptions

--- @class DistantApiSearchQueryCondition
--- @field type 'contains'|'ends_with'|'equals'|'or'|'regex'|'starts_with'
--- @field value string|DistantApiSearchQueryCondition[]

--- @class DistantApiSearchQueryOptions
--- @field allow_file_types? 'dir'|'file'|'symlink'[]
--- @field include? DistantApiSearchQueryCondition
--- @field exclude? DistantApiSearchQueryCondition
--- @field follow_symbolic_links? boolean
--- @field limit? integer
--- @field max_depth? integer
--- @field pagination? integer

--- @param opts {transport:DistantApiTransport}
--- @return DistantApiSearch
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
--- @param payload table
--- @return boolean #true if valid payload, otherwise false
function M:handle(payload)
    if payload.type == 'search_started' then
        local id = assert(tonumber(payload.id), 'Malformed search started event! Missing id.')
        if self:id() then
            log.fmt_warn('Received a "search_started" event with id %s, but already started with id %s', id, self:id())
        end
        self.__internal.id = id
        self.__internal.status = 'active'
        return true
    elseif payload.type == 'search_done' then
        local id = assert(tonumber(payload.id), 'Malformed search done event! Missing id.')
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
        local id = assert(tonumber(payload.id), 'Malformed search started event! Missing id.')
        local matches = assert(payload.matches, 'Malformed search results event! Missing matches.')
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

--- Starts the search. If a callback is provided, matches will be returned asynchronously,
--- otherwise they will be returned synchronously.
---
--- Alternatively, an `on_results` function can be provided to receive results asynchronously
--- as they are received.
---
--- @param opts {query:DistantApiSearchQuery, on_results?:fun(matches:DistantApiSearchMatch[]), timeout?:number, interval?:number}
--- @param cb? fun(err?:string, matches?:DistantApiSearchMatch[])
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
    self.__internal.timeout = opts.timeout
    self.__internal.interval = opts.timeout

    self.__internal.transport:send_async({
        payload = {
            type = 'search',
            query = opts.query,
        },
        more = function(payload)
            local ty = payload.type
            return ty == 'search_started' or ty == 'search_results' or ty == 'search_done'
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
        local err, msg = rx()
        return err or msg.err, msg.matches
    end
end

--- Cancels the search if running asynchronously.
--- @param cb? fun(err?:string, payload?:{type:'ok'}) #optional callback to report cancel confirmation
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
