local DistantApiCmdBuilder = require('distant-core.builder.api')
local DistantCmdBuilder = require('distant-core.builder.cmd')
local DistantConnectCmdBuilder = require('distant-core.builder.connect')
local DistantLaunchCmdBuilder = require('distant-core.builder.launch')
local DistantShellCmdBuilder = require('distant-core.builder.shell')
local DistantSpawnCmdBuilder = require('distant-core.builder.spawn')

--- @class DistantCmdBuilder
--- @field manager DistantManagerCmdBuilder
--- @field server DistantServerCmdBuilder
local M = {
    manager = require('distant-core.builder.manager'),
    server = require('distant-core.builder.server'),
}
M.__index = M

--- @return DistantApiCmdBuilder
function M.api()
    return DistantApiCmdBuilder:new()
end

--- @param cmd string|string[]
--- @param opts? {allowed?:string[]}
--- @return DistantCmdBuilder
function M.cmd(cmd, opts)
    return DistantCmdBuilder:new(cmd, opts)
end

--- @param destination string
--- @return DistantConnectCmdBuilder
function M.connect(destination)
    return DistantConnectCmdBuilder:new(destination)
end

--- @param destination string
--- @return DistantLaunchCmdBuilder
function M.launch(destination)
    return DistantLaunchCmdBuilder:new(destination)
end

--- @param cmd? string|string[]
--- @return DistantShellCmdBuilder
function M.shell(cmd)
    return DistantShellCmdBuilder:new(cmd)
end

--- @param cmd string|string[]
--- @return DistantSpawnCmdBuilder
function M.spawn(cmd)
    return DistantSpawnCmdBuilder:new(cmd)
end

return M
