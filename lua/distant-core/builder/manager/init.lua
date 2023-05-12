local DistantManagerListCmdBuilder = require('distant-core.builder.manager.list')
local DistantManagerListenCmdBuilder = require('distant-core.builder.manager.listen')
local DistantManagerSelectCmdBuilder = require('distant-core.builder.manager.select')

--- @class distant.core.builder.ManagerCmdBuilder
local M = {}
M.__index = M

--- @return distant.core.builder.manager.ListCmdBuilder
function M.list()
    return DistantManagerListCmdBuilder:new()
end

--- @return distant.core.builder.manager.ListenCmdBuilder
function M.listen()
    return DistantManagerListenCmdBuilder:new()
end

--- @param connection? string
--- @return distant.core.builder.manager.SelectCmdBuilder
function M.select(connection)
    return DistantManagerSelectCmdBuilder:new(connection)
end

return M
