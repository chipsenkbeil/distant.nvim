local log   = require('distant-core').log
local state = require('distant.state')

--- @class EditorCancelSearchOpts
--- @field timeout number|nil #Maximum time to wait for a response
--- @field interval number|nil #Time in milliseconds to wait between checks for a response

--- Cancels the active search if there is one
--- @param opts EditorCancelSearchOpts
return function(opts)
    log.fmt_trace('editor.cancel_search(%s)', opts)

    if state.search ~= nil then
        local id = state.search.searcher.id
        if not state.search.searcher.done then
            state.search.searcher.cancel(opts, function(err)
                assert(not err, err)
                vim.notify('Cancelled search ' .. id)
            end)
        end
    end
end
