local fn = require('distant.fn')
local log = require('distant.log')
local ui = require('distant.ui')

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

    opts.on_match = function(match)
        print(vim.inspect(match))

        if type(user_on_match) == 'function' then
            return user_on_match(match)
        end
    end

    opts.on_done = function(matches)
        for _, match in ipairs(matches or {}) do
            print(vim.inspect(match))
        end

        if type(user_on_done) == 'function' then
            return user_on_done(matches)
        end
    end

    local err, searcher = fn.search(opts)
    assert(not err, err)
end
