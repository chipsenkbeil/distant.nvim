local DistantServerListenCmdBuilder = require('distant-core.builder.server.listen')

--- @class distant.core.builder.ServerCmdBuilder
local M = {}
M.__index = M

--- @return distant.core.builder.server.ListenCmdBuilder
function M.listen()
    return DistantServerListenCmdBuilder:new()
end

return M
