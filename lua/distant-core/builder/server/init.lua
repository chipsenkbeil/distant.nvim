local DistantServerListenCmdBuilder = require('distant-core.builder.server.listen')

--- @class distant.builder.ServerCmdBuilder
local M = {}
M.__index = M

--- @return distant.builder.server.ListenCmdBuilder
function M.listen()
    return DistantServerListenCmdBuilder:new()
end

return M
