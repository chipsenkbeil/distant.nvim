local fn = require('distant.fn')
local log = require('distant.log')

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
        local item = {
            filename = tostring(match.path),
        }

        if not vim.startswith(item.filename, 'distant://') then
            item.filename = 'distant://' .. item.filename
        end

        -- Contents have more information to provide than filenames
        if match.type == 'contents' then
            item.lnum = tonumber(match.line_number)
            if match.submatches[1] then
                item.col = match.submatches[1].start + 1
            end

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
        elseif match.type == 'path' then
            item.lnum = 1
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

--- Opens a new window to display system info
--- @param opts EditorSearchOpts
return function(opts)
    opts = opts or {}
    log.trace('editor.search(%s)', opts)
    vim.validate({ opts = { opts, 'table' } })

    -- If it's a string, we want to transform it into a standard query
    if type(opts.query) == 'string' then
        local regex = opts.query
        opts.query = {
            path = '.',
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
        print('Search matched ' .. tostring(match_cnt) .. ' times')

        if user_on_results ~= nil and type(user_on_results) == 'function' then
            return user_on_results(matches)
        end
    end

    opts.on_done = function(matches)
        matches = matches or {}
        match_cnt = match_cnt + #matches

        add_matches_to_qflist(qflist_id, matches)
        print('Search finished with ' .. tostring(match_cnt) .. ' matches')

        if user_on_done ~= nil and type(user_on_done) == 'function' then
            return user_on_done(matches)
        end
    end

    -- Callback is triggered when search is started
    fn.search(opts, function(err, searcher)
        assert(not err, err)

        -- Create an empty list to be populated with results
        vim.fn.setqflist({}, ' ', {
            title = 'DistantSearch ' .. searcher.query.condition.value
        })

        -- Set our list id by grabbing the id of the latest qflist
        qflist_id = vim.fn.getqflist({ id = 0 }).id

        print('Started search ' .. tostring(searcher.id))

        vim.cmd([[ copen ]])
    end)
end
