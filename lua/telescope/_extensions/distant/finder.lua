local log = require('distant-core.log')
local plugin = require('distant')

local DEFAULT_LIMIT = 10000
local DISPLAY_LINE_LEN = 40

--- @class telescope.distant.finder.Settings
--- @field minimum_len number #minimum length of input before sending a query

--- @class telescope.distant.Finder
--- @field query distant.core.api.search.Query
--- @field settings telescope.distant.finder.Settings
--- @field results telescope.distant.finder.Entry[]
--- @field private __searcher? distant.core.api.Searcher #active search (internal)
local M = {}
M.__index = M

--- Invoking itself will call the internal `_find` method
M.__call = function(t, ...)
    return t:__find(...)
end

--- @class telescope.distant.finder.Entry
--- @field value any #required, but can be anything
--- @field ordinal string #text used for filtering
--- @field display string|function #either the text to display or a function that takes the entry and converts it into a string
--- @field valid? boolean #if set to false, the entry will not be displayed by the picker
--- @field filename? string #path of file that will be opened (if set)
--- @field bufnr? number #buffer that will be opened (if set)
--- @field lnum? number #jumps to this line (if set)
--- @field col? number #jumps to this column (if set)

--- @param match distant.core.api.search.Match
--- @return telescope.distant.finder.Entry|nil
local function make_entry(match)
    local components = plugin.buf.name.parse({ name = match.path })
    local entry = {
        value = match,
        valid = true,
        ordinal = match.path,
        display = match.path,
        filename = 'distant://' .. components.path,
    }

    if match.type == 'path' then
        return entry
    elseif match.type == 'contents' then
        -- Skip binary matches
        if type(match.lines) ~= 'string' then
            return
        end

        entry.lnum = match.line_number
        if match.submatches[1] then
            -- Our column is 0-based and we need to convert it to 1-based
            entry.col = match.submatches[1].start + 1
        end

        local lines = match.lines
        --- @cast lines string

        -- :line,col:{LINE}
        local suffix = ':'
            .. entry.lnum .. ','
            .. (entry.col or 1) .. ':'
            .. lines:sub(1, DISPLAY_LINE_LEN)
            .. (#lines > DISPLAY_LINE_LEN and '...' or '')

        -- Clean up the text to prevent it being a blob/string buffer
        -- by removing control characters and null (\0) that can appear
        -- when searching text by escaping it
        suffix = suffix:gsub('%z', '\\0'):gsub('%c', '')

        entry.ordinal = entry.ordinal .. suffix
        entry.display = entry.display .. suffix

        return entry
    end
end

--- @class telescope.distant.finder.NewOpts
--- @field query distant.core.api.search.Query #query to execute whose results will be captured
--- @field settings telescope.distant.finder.Settings|nil

--- Creates a new finder.
--- @param opts telescope.distant.finder.NewOpts
--- @return telescope.distant.Finder
function M:new(opts)
    opts = opts or {}

    assert(opts.query, 'query is required')

    -- Default condition to regex (value is filled in by prompt)
    opts.query.condition = opts.query.condition or { type = 'regex' }

    -- Default target to file contents
    opts.query.target = opts.query.target or 'contents'

    -- Fall back to current directory if no path provided
    opts.query.paths = opts.query.paths or { '.' }

    -- Define pagination and limit if not provided so we get a stream of results
    opts.query.options = opts.query.options or {}
    opts.query.options.limit = opts.query.options.limit or DEFAULT_LIMIT
    opts.query.options.pagination = (opts.query.options.pagination
        or math.max(math.floor(opts.query.options.limit / 100), 1))

    -- Results is empty until find is started
    local obj = setmetatable({
        query = opts.query,
        settings = vim.tbl_extend('keep', opts.settings or {}, {
            minimum_len = 1,
        }),
        results = {},
    }, self)

    assert(obj.settings.minimum_len > 0, 'minimum_len must be > 0')

    return obj
end

--- Spawns the search task.
--- @private
function M:__find(prompt, process_result, process_complete)
    -- Make sure we aren't already searching by stopping anything running
    self:close(function(err)
        assert(not err, err)

        if string.len(prompt) < self.settings.minimum_len then
            log.fmt_debug('Skipping prompt %s as it is less than %s', prompt, self.settings.minimum_len)
            process_complete()
            return
        end

        -- Build our query using the template query and replacing the value
        -- with that of the prompt
        local opts = { query = vim.deepcopy(self.query) }
        opts.query.condition.value = prompt

        -- On results, we process them
        opts.on_results = function(matches)
            for _, match in ipairs(matches) do
                local entry = make_entry(match)
                table.insert(self.results, entry)

                -- If this returns true, we need to stop
                if process_result(entry) then
                    --- @diagnostic disable-next-line:redefined-local
                    self:close(function(err)
                        assert(not err, err)
                    end)

                    return
                end
            end
        end

        -- Search using the active client
        --- @diagnostic disable-next-line:redefined-local
        local err, searcher = plugin.api.search(opts, function(err, matches)
            assert(not err, tostring(err))

            for _, match in ipairs(matches) do
                local entry = make_entry(match)
                table.insert(self.results, entry)

                -- If this returns true, we need to stop early
                if process_result(entry) then
                    break
                end
            end

            process_complete()
            self.__searcher = nil
        end)

        assert(not err, tostring(err))
        self.__searcher = searcher
    end)
end

--- Cancels the finder's ongoing task.
---
--- @private
--- @param cb fun(err:string|nil)
function M:close(cb)
    cb = cb or function()
    end
    self.results = {}

    local searcher = self.__searcher
    if searcher ~= nil then
        if not searcher:is_done() then
            searcher:cancel(function(err)
                cb(tostring(err))
            end)
        else
            cb()
        end

        self.__searcher = nil
    else
        cb()
    end
end

return M
