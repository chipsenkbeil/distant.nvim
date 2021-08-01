local c = require('distant.constants')

local session = {}

-- Clears the session, returning any output executing the binary
session.clear = function()
    return vim.fn.system(c.BINARY_NAME .. ' session clear')
end

return session
