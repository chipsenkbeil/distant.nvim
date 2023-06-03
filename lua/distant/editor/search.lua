local plugin             = require('distant')
local log                = require('distant-core').log
local utils              = require('distant-core').utils

local callable           = utils.callable

local DEFAULT_PAGINATION = 10
local MAX_LINE_LEN       = 100

--- @class neovim.qflist.Item
--- @field bufnr number #buffer that has the file name
--- @field module string #module name
--- @field lnum integer #line number within buffer (index 1)
--- @field end_lnum integer #line number of final line if multiline (index 1)
--- @field col integer #column number within buffer (index 1)
--- @field end_col integer #col number of final column if item has range (index 1)
--- @field vcol boolean #true if 'col' is visual column, false if byte index
--- @field nr number #error number
--- @field pattern string #search pattern used to locate error
--- @field text string #description of error
--- @field type string #type of error such as 'E' or '1'
--- @field valid boolean #if true, recognized as an error message

--- Add matches to qflist
--- @param id number #id of quickfix list
--- @param matches distant.core.api.search.Match[] #match(s) to add
local function add_matches_to_qflist(id, matches)
    -- Quit if nothing to add
    if #matches == 0 then
        return
    end

    local items = {}

    for _, match in ipairs(matches) do
        local filename = plugin.buf.name.build({
            scheme = 'distant',
            connection = plugin:active_client_id(),
            path = tostring(match.path),
        })
        local item = {
            -- Add a more friendly name for display only
            module = tostring(match.path),
            -- Has no buffer as of yet (we create it)
            bufnr = -1,
            -- Not an error, but marking as valid so we can
            -- traverse using :cnext and :cprevious
            valid = 1,
        }

        -- Assign line and column information
        item.lnum = tonumber(match.line_number) or 1
        item.end_lnum = item.lnum
        if match.submatches[1] then
            item.col = match.submatches[1].start + 1
            item.end_col = match.submatches[1]['end']
        end

        item.bufnr = plugin.buf.find_bufnr({ path = filename })

        -- Create the buffer as unlisted and not scratch for the filename
        if not item.bufnr then
            log.fmt_trace('%s does not exist, so creating new buffer', filename)
            item.bufnr = vim.api.nvim_create_buf(false, false)
            if item.bufnr == 0 then
                error('Failed to create unlisted buffer for ' .. filename)
            end
            vim.api.nvim_buf_set_name(item.bufnr, filename)
            log.fmt_trace('created buf %s for %s', item.bufnr, filename)
        else
            log.fmt_trace('reusing buf %s for %s', item.bufnr, filename)
        end

        -- If our buffer has not been loaded from remote file, we extend
        -- it to be as long as needed to support tracked line
        --
        -- Otherwise, the file has already been opened and should contain
        -- the lines we would be tracking
        if not plugin.buf(item.bufnr).has_data() then
            local line_cnt = vim.api.nvim_buf_line_count(item.bufnr)
            local additional_line_cnt = item.end_lnum - line_cnt
            if additional_line_cnt > 0 then
                log.fmt_trace('growing buf %s by %s lines', item.bufnr, additional_line_cnt)
                vim.api.nvim_buf_set_lines(
                    item.bufnr,
                    -1,
                    -1,
                    true,
                    vim.fn['repeat']({ '' }, additional_line_cnt)
                )
                vim.api.nvim_buf_set_option(item.bufnr, 'modified', false)
            end
        end

        -- Contents have more information to provide than filenames
        if match.type == 'contents' then
            -- Update our filename to include the line and column since
            -- we need to force a jump to that position instead of
            -- relying on quickfix, which tries to jump before the content
            -- has been loaded
            --
            -- Format is distant://path/to/file.txt:line,col where the
            -- suffix of :line,col is used to indicate where to go
            -- item.filename = item.filename .. ':' .. item.lnum .. ',' .. (item.col or 1)

            -- If we have text, assign up to 100 characters, truncating with suffix ...
            -- if we have a longer line
            if type(match.lines) == 'string' then
                local text = match.lines

                --- @cast text string
                item.text = text

                if #item.text > MAX_LINE_LEN then
                    item.text = item.text:sub(1, MAX_LINE_LEN - 3) .. '...'
                end

                -- Clean up the text to prevent it being a blob/string buffer
                -- by removing control characters and null (\0) that can appear
                -- when searching text by escaping it
                item.text = item.text:gsub('%z', '\\0'):gsub('%c', '')
            end
        end

        table.insert(items, item)
    end

    vim.fn.setqflist({}, 'a', { id = id, items = items })
end

--- Used by the editor to both perform a search and cancel it.
--- @class distant.editor.Search
--- @field private __active_search {qfid?:number, searcher?:distant.core.api.Searcher}
local M = { __active_search = {} }

--- @class distant.editor.SearchOpts
--- @field query distant.core.api.search.Query|string #if a string, will treat as regex to target file contents
--- @field on_start? fun(id:number) #if provided, called with the search id when started
--- @field on_results? fun(matches:distant.core.api.search.Match[]) #if provided, will be provided matches as they appear
--- @field timeout? number #Maximum time to wait for a response
--- @field interval? number #Time in milliseconds to wait between checks for a response

--- Performs a search using the provided query, displaying results in a new quickfix list.
---
--- @param opts distant.editor.SearchOpts
--- @param cb? fun(err?:distant.core.api.Error, matches?:distant.core.api.search.Match[]) #if provided, will be invoked with matches once finished
function M.search(opts, cb)
    opts = opts or {}
    log.trace('editor.search(%s)', opts)
    vim.validate({ opts = { opts, 'table' } })

    -- If it's a string, we want to transform it into a standard query
    local query = opts.query
    if type(query) == 'string' then
        local regex = query
        query = {
            paths = { '.' },
            target = 'contents',
            condition = {
                type = 'regex',
                value = regex,
            }
        }
    end

    local user_on_start = opts.on_start
    local user_on_results = opts.on_results
    local user_on_done = cb

    if type(query.options) ~= 'table' then
        query.options = {}
    end

    query.options.pagination = query.options.pagination or DEFAULT_PAGINATION

    -- Keep track of how many matches we have
    --- @type integer|nil
    local qflist_id
    local match_cnt = 0

    -- For each set of matches, we add them to our quickfix list
    --- @param matches distant.core.api.search.Match[]
    local function on_results(matches)
        if qflist_id ~= nil and #matches > 0 then
            add_matches_to_qflist(qflist_id, matches)
        end
        match_cnt = match_cnt + #matches
        vim.notify('Search matched ' .. tostring(match_cnt) .. ' times')

        if user_on_results and callable(user_on_results) then
            return user_on_results(matches)
        end
    end

    --- @param id integer
    local function on_start(id)
        -- Create an empty list to be populated with results
        vim.fn.setqflist({}, ' ', {
            title = 'DistantSearch ' .. id,
            context = { distant = true, search_id = id },
        })

        -- Set our list id by grabbing the id of the latest qflist
        qflist_id = vim.fn.getqflist({ id = 0 }).id

        -- Update state with our active search
        M.__active_search.qfid = qflist_id

        vim.notify('Started search ' .. tostring(id))

        vim.cmd([[ copen ]])

        if user_on_start and callable(user_on_start) then
            return user_on_start(id)
        end
    end

    --- @param err? distant.core.api.Error
    --- @param matches? distant.core.api.search.Match[]
    local function on_done(err, matches)
        -- Process any final matches
        if matches then
            match_cnt = match_cnt + #matches

            if qflist_id ~= nil and #matches > 0 then
                add_matches_to_qflist(qflist_id, matches)
            end
        end

        -- Report the error if we have one
        if err then
            vim.notify('Search encountered an error: ' .. tostring(err))
        end

        vim.notify('Search finished with ' .. tostring(match_cnt) .. ' matches')

        -- Reset the active search to be nothing
        M.__active_search.qfid = nil
        M.__active_search.searcher = nil

        if user_on_done and callable(user_on_done) then
            return user_on_done(err, matches)
        end
    end

    local search_opts = {
        query = query,
        on_results = on_results,
        on_start = on_start,
        timeout = opts.timeout,
        interval = opts.interval,
    }

    -- Stop any existing search being done by the editor
    if M.__active_search ~= nil and M.__active_search.searcher ~= nil and not M.__active_search.searcher:is_done() then
        M.__active_search.searcher:cancel(function(err, _)
            assert(not err, tostring(err))

            -- Search using the active client
            --- @type distant.core.api.Error|nil, distant.core.api.Searcher|nil
            local err, searcher = plugin.api.search(search_opts, on_done)
            assert(not err, tostring(err))

            M.__active_search.searcher = searcher
        end)
    else
        -- Search using the active client
        --- @type distant.core.api.Error|nil, distant.core.api.Searcher|nil
        local err, searcher = plugin.api.search(search_opts, on_done)
        assert(not err, tostring(err))
        M.__active_search.searcher = searcher
    end
end

--- Cancels the active search if there is one.
function M.cancel()
    log.fmt_trace('distant.editor.search.cancel()')

    local searcher = M.__active_search.searcher
    if searcher then
        M.__active_search.searcher = nil
        if searcher:status() == 'active' then
            local id = assert(searcher:id())
            searcher:cancel(function(err)
                assert(not err, tostring(err))
                vim.notify('Cancelled search ' .. id)
            end)
        end
    end
end

return M
