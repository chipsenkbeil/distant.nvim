local state = require('distant.state')

--- Performs a client wrapping of the given cmd, lsp, or shell
--- using the active client. Will fail if client is not initialized.
---
--- @param opts distant.client.WrapOpts
--- @return string|string[]
return function(opts)
    local client = assert(
        state.client,
        'Client must be initialized before invoking wrap'
    )

    return client:wrap(opts)
end
