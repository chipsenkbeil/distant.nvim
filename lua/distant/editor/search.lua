local fn = require('distant.fn')

local log = require('distant-core.log')
local state = require('distant-core.state')
local vars = require('distant-core.vars')

local DEFAULT_PAGINATION = 10
local MAX_LINE_LEN = 100

--- Add matches to qflist
--- @param id number #id of quickfix list
--- @param matches DistantSearchMatch[] #match(s) to add
local function add_matches_to_qflist(id, matches)
    -- Quit if nothing to add
    if #matches == 0 then
        return
    end

    local items = {}

    for _, match in ipairs(matches) do
        local filename = 'distant://' .. tostring(match.path)
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

        item.bufnr = vars.buf.find_with_path(match.path) or -1

        -- Create the buffer as unlisted and not scratch for the filename
        if item.bufnr == -1 then
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
        if vars.buf(item.bufnr).remote_path.is_unset() then
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
            if match.lines.type == 'text' then
                item.text = match.lines.value
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

--- @class EditorSearchOpts
--- @field query DistantSearchQuery|string
--- @field on_results nil|fun(matches:DistantSearchMatch[])
--- @field on_done nil|fun(matches:DistantSearchMatch[])
--- @field timeout number|nil #Maximum time to wait for a response
--- @field interval number|nil #Time in milliseconds to wait between checks for a response

--- Performs a search using the provided query, displaying results in a new quickfix list
--- @param opts EditorSearchOpts
return function(opts)
    opts = opts or {}
    log.trace('editor.search(%s)', opts)
    vim.validate({ opts = { opts, 'table' } })

    -- If it's a string, we want to transform it into a standard query
    if type(opts.query) == 'string' then
        local regex = opts.query
        opts.query = {
            paths = { '.' },
            target = 'contents',
            condition = {
                type = 'regex',
                value = regex,
            }
        }
    end

    local user_on_results = opts.on_results
    local user_on_done = opts.on_done

    if type(opts.query.options) ~= 'table' then
        opts.query.options = {}
    end

    opts.query.options.pagination = opts.query.options.pagination or DEFAULT_PAGINATION

    -- Keep track of how many matches we have
    local qflist_id
    local match_cnt = 0

    -- For each set of matches, we add them to our quickfix list
    opts.on_results = function(matches)
        add_matches_to_qflist(qflist_id, matches)
        match_cnt = match_cnt + #matches
        vim.notify('Search matched ' .. tostring(match_cnt) .. ' times')

        if user_on_results ~= nil and type(user_on_results) == 'function' then
            return user_on_results(matches)
        end
    end

    opts.on_done = function(matches)
        matches = matches or {}
        match_cnt = match_cnt + #matches

        add_matches_to_qflist(qflist_id, matches)
        vim.notify('Search finished with ' .. tostring(match_cnt) .. ' matches')

        if user_on_done ~= nil and type(user_on_done) == 'function' then
            return user_on_done(matches)
        end
    end

    local function do_search()
        -- Callback is triggered when search is started
        fn.search(opts, function(err, searcher)
            assert(not err, err)

            -- Create an empty list to be populated with results
            vim.fn.setqflist({}, ' ', {
                title = 'DistantSearch ' .. searcher.query.condition.value,
                context = { distant = true, search_id = searcher.id },
            })

            -- Set our list id by grabbing the id of the latest qflist
            qflist_id = vim.fn.getqflist({ id = 0 }).id

            -- Update state with our active search
            state.search = {
                qfid = qflist_id,
                searcher = searcher,
            }

            vim.notify('Started search ' .. tostring(searcher.id))

            vim.cmd([[ copen ]])
        end)
    end

    -- Stop any existing search being done by the editor
    if state.search ~= nil then
        local searcher = state.search.searcher
        if not searcher.done then
            searcher.cancel(function(err)
                assert(not err, err)
                do_search()
            end)
        else
            do_search()
        end
    else
        do_search()
    end
end
