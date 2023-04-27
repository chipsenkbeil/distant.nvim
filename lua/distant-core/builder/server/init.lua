local DistantServerListenCmdBuilder = require('distant-core.builder.server.listen')

--- @class DistantServerCmdBuilder
local M = {}
M.__index = M

--- @return DistantServerListenCmdBuilder
function M.listen()
    return DistantServerListenCmdBuilder:new()
end

return M
