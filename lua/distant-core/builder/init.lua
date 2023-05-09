local DistantApiCmdBuilder = require('distant-core.builder.api')
local DistantCmdBuilder = require('distant-core.builder.cmd')
local DistantConnectCmdBuilder = require('distant-core.builder.connect')
local DistantLaunchCmdBuilder = require('distant-core.builder.launch')
local DistantShellCmdBuilder = require('distant-core.builder.shell')
local DistantSpawnCmdBuilder = require('distant-core.builder.spawn')

--- @alias distant.core.log.Level
--- | 'trace'
--- | 'debug'
--- | 'info'
--- | 'warn'
--- | 'error'
--- | 'off'

--- @class distant.builder.CmdBuilder
--- @field manager distant.builder.ManagerCmdBuilder
--- @field server distant.builder.ServerCmdBuilder
local M = {
    manager = require('distant-core.builder.manager'),
    server = require('distant-core.builder.server'),
}
M.__index = M

--- @return distant.builder.ApiCmdBuilder
function M.api()
    return DistantApiCmdBuilder:new()
end

--- @param cmd string|string[]
--- @param opts? {allowed?:string[]}
--- @return distant.builder.CmdBuilder
function M.cmd(cmd, opts)
    return DistantCmdBuilder:new(cmd, opts)
end

--- @param destination string
--- @return distant.builder.ConnectCmdBuilder
function M.connect(destination)
    return DistantConnectCmdBuilder:new(destination)
end

--- @param destination string
--- @return distant.builder.LaunchCmdBuilder
function M.launch(destination)
    return DistantLaunchCmdBuilder:new(destination)
end

--- @param cmd? string|string[]
--- @return distant.builder.ShellCmdBuilder
function M.shell(cmd)
    return DistantShellCmdBuilder:new(cmd)
end

--- @param cmd string|string[]
--- @return distant.builder.SpawnCmdBuilder
function M.spawn(cmd)
    return DistantSpawnCmdBuilder:new(cmd)
end

return M
