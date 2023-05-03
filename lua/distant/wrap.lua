local state = require('distant-core').state

--- Performs a client wrapping of the given cmd, lsp, or shell
--- using the active client. Will fail if client is not initialized.
---
--- @param args ClientWrapArgs
--- @return string|string[]
return function(args)
    local client = assert(
        state.client,
        'Client must be initialized before invoking wrap'
    )

    return client:wrap(args)
end
