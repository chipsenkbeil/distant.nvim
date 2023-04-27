local DistantManagerListCmdBuilder = require('distant-core.builder.manager.list')
local DistantManagerListenCmdBuilder = require('distant-core.builder.manager.listen')
local DistantManagerSelectCmdBuilder = require('distant-core.builder.manager.select')

--- @class DistantManagerCmdBuilder
local M = {}
M.__index = M

--- @return DistantManagerListCmdBuilder
function M.list()
    return DistantManagerListCmdBuilder:new()
end

--- @return DistantManagerListenCmdBuilder
function M.listen()
    return DistantManagerListenCmdBuilder:new()
end

--- @param connection? string
--- @return DistantManagerSelectCmdBuilder
function M.select(connection)
    return DistantManagerSelectCmdBuilder:new(connection)
end

return M
