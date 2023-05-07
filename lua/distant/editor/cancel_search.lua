local log   = require('distant-core').log
local state = require('distant.state')

--- Cancels the active search if there is one
return function()
    log.fmt_trace('editor.cancel_search()')

    local searcher = state.active_search.searcher
    if searcher then
        state.active_search.searcher = nil
        if searcher:status() == 'active' then
            local id = assert(searcher:id())
            searcher:cancel(function(err)
                assert(not err, tostring(err))
                vim.notify('Cancelled search ' .. id)
            end)
        end
    end
end
