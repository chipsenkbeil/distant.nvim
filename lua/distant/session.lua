local g = require('distant.internal.globals')

local session = {}

--- Clears the session, returning any output executing the binary
session.clear = function()
    vim.fn.system(g.settings.binary_name .. ' session clear')
end

--- Check if a session exists
---
--- @return true if exists, otherwise false
session.exists = function()
    vim.fn.system(g.settings.binary_name .. ' session exists')
    return vim.v.shell_error == 0
end

--- Retrieve session information
---
--- @return {'host' = ...; 'port' = ...} if available, otherwise nil
session.info = function()
    local info = vim.fn.system(g.settings.binary_name .. ' session info --mode json')
    if vim.v.shell_error == 0 then
        return vim.fn.json_decode(info)
    else
        return nil
    end
end

return session
