local fn = require('distant.fn')
local log = require('distant.log')

--- @class EditorSearchOpts
--- @field query DistantSearchQuery|string
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

    local user_on_match = opts.on_match
    local user_on_done = opts.on_done

    local last_path = nil
    local match_cnt = 0
    opts.on_match = function(match)
        if match.type == 'contents' then
            -- If start of a new path of results, add a newline
            if last_path ~= nil and match.path ~= last_path then
                print('')
            end

            if match.path ~= last_path then
                print(match.path)
            end

            if match.lines.type == 'text' then
                print(tostring(match.line_number) .. ':' .. match.lines.value)
            elseif match.lines.type == 'bytes' then
                print(tostring(match.line_number) .. ': {BINARY DATA}')
            else
                error('Unknown match line type: ' .. match.lines.type)
            end
        else
            print(match.path)
        end

        match_cnt = match_cnt + 1

        if type(user_on_match) == 'function' then
            return user_on_match(match)
        end
    end

    opts.on_done = function(matches)
        matches = matches or {}
        match_cnt = match_cnt + #matches

        for _, match in ipairs(matches) do
            print(vim.inspect(match))
        end

        if type(user_on_done) == 'function' then
            return user_on_done(matches)
        end

        if match_cnt == 0 then
            error('No match found')
        end
    end

    -- Callback is triggered when search is started
    fn.search(opts, function(err)
        assert(not err, err)
    end)
end
