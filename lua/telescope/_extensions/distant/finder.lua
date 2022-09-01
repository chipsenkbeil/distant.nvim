local fn = require('distant.fn')

--- Display results in batches of 10 by default
local DEFAULT_PAGINATION = 10

local DISPLAY_LINE_LEN = 40

--- @class DistantFinder
--- @field query DistantSearchQuery
--- @field results DistantFinderEntry[]
--- @field __searcher DistantSearcher|nil #active searcher (internal)
local Finder = {}
Finder.__index = Finder

--- Invoking itself will call the internal `_find` method
Finder.__call = function(t, ...)
    return t:__find(...)
end

--- @class DistantFinderEntry
--- @field value any #required, but can be anything
--- @field ordinal string #text used for filtering
--- @field display string|function #either the text to display or a function that takes the entry and converts it into a string
--- @field valid boolean|nil #if set to false, the entry will not be displayed by the picker
--- @field filename string|nil #path of file that will be opened (if set)
--- @field bufnr number|nil #buffer that will be opened (if set)
--- @field lnum number|nil #jumps to this line (if set)
--- @field col number|nil #jumps to this column (if set)

--- @param match DistantSearchMatch
--- @return DistantFinderEntry|nil
local function make_entry(match)
    local path_with_scheme = match.path
    if not vim.startswith(path_with_scheme, 'distant://') then
        path_with_scheme = 'distant://' .. path_with_scheme
    end

    local entry = {
        value = match,
        valid = true,
        ordinal = match.path,
        display = match.path,
        filename = path_with_scheme,
    }

    if match.type == 'path' then
        return entry
    elseif match.type == 'contents' then
        -- Skip binary matches
        if match.lines.type == 'bytes' then
            return
        end

        entry.lnum = match.line_number
        if match.submatches[1] then
            -- Our column is 0-based and we need to convert it to 1-based
            entry.col = match.submatches[1].start + 1
        end

        -- :line,col:{LINE}
        local suffix = ':'
            .. entry.lnum .. ','
            .. (entry.col or 1) .. ':'
            .. match.lines.value:sub(1, DISPLAY_LINE_LEN)
            .. (#match.lines.value > DISPLAY_LINE_LEN and '...' or '')

        entry.ordinal = entry.ordinal .. suffix
        entry.display = entry.display .. suffix

        return entry
    end
end

--- @class DistantFinderOpts
--- @field query DistantSearchQuery #query to execute whose results will be captured

--- Creates a new finder that takes
--- @param opts DistantFinderOpts
--- @return DistantFinder
function Finder:new(opts)
    opts = opts or {}

    assert(opts.query, 'query is required')

    -- Default condition to regex (value is filled in by prompt)
    opts.query.condition = opts.query.condition or { type = 'regex' }

    -- Default target to file contents
    opts.query.target = opts.query.target or 'contents'

    -- Fall back to current directory if no path provided
    opts.query.paths = opts.query.paths or { '.' }

    -- Define pagination if not provided so we get a stream of results
    opts.query.options = opts.query.options or {}
    opts.query.options.pagination = opts.query.options.pagination or DEFAULT_PAGINATION

    -- Results is empty until find is started
    local obj = setmetatable({
        query = opts.query,
        results = {},
    }, self)

    return obj
end

--- Spawns the search task
function Finder:__find(prompt, process_result, process_complete)
    vim.pretty_print('Finder:__find:', prompt, process_result, process_complete)

    -- Make sure we aren't already searching by stopping anything running
    self:close(function(err)
        vim.pretty_print('close', err)
        assert(not err, err)

        -- Empty prompt is not supported
        if vim.trim(prompt) == '' then
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
                process_result(entry)
            end
        end

        -- On completion, we process dangling results
        opts.on_done = function(matches)
            for _, match in ipairs(matches) do
                local entry = make_entry(match)
                table.insert(self.results, entry)
                process_result(entry)
            end

            process_complete()
        end

        fn.search(opts, function(err, searcher)
            assert(not err, err)
            self.__searcher = searcher
        end)
    end)
end

--- Cancels the finder's ongoing task
--- @param cb fun(err:string|nil)
function Finder:close(cb)
    cb = cb or function() end
    self.results = {}

    if self.__searcher ~= nil then
        if not self.__searcher.done then
            self.__searcher.cancel(function(err)
                cb(err)
            end)
        end

        self.__searcher = nil
    else
        cb()
    end
end

return Finder
