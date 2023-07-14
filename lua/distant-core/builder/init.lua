local DistantApiCmdBuilder = require('distant-core.builder.api')
local DistantCmdBuilder = require('distant-core.builder.cmd')
local DistantConnectCmdBuilder = require('distant-core.builder.connect')
local DistantLaunchCmdBuilder = require('distant-core.builder.launch')
local DistantShellCmdBuilder = require('distant-core.builder.shell')
local DistantSpawnCmdBuilder = require('distant-core.builder.spawn')

--- @alias distant.core.log.Level
--- | '"trace"'
--- | '"debug"'
--- | '"info"'
--- | '"warn"'
--- | '"error"'
--- | '"off"'

--- @alias distant.core.builder.Format
--- | '"json"'
--- | '"shell"'

--- @class distant.core.builder.CmdBuilder
--- @field manager distant.core.builder.ManagerCmdBuilder
--- @field server distant.core.builder.ServerCmdBuilder
local M = {}
M.manager = require('distant-core.builder.manager')
M.server = require('distant-core.builder.server')
M.__index = M

--- @return distant.core.builder.ApiCmdBuilder
function M.api()
    return DistantApiCmdBuilder:new()
end

--- @param cmd string|string[]
--- @param opts? {allowed?:string[]}
--- @return distant.core.builder.CmdBuilder
function M.cmd(cmd, opts)
    return DistantCmdBuilder:new(cmd, opts)
end

--- @param destination string
--- @return distant.core.builder.ConnectCmdBuilder
function M.connect(destination)
    return DistantConnectCmdBuilder:new(destination)
end

--- @param destination string
--- @return distant.core.builder.LaunchCmdBuilder
function M.launch(destination)
    return DistantLaunchCmdBuilder:new(destination)
end

--- @param cmd? string|string[]
--- @return distant.core.builder.ShellCmdBuilder
function M.shell(cmd)
    return DistantShellCmdBuilder:new(cmd)
end

--- @param cmd string|string[]
--- @param use_cmd_arg? boolean
--- @return distant.core.builder.SpawnCmdBuilder
function M.spawn(cmd, use_cmd_arg)
    return DistantSpawnCmdBuilder:new(cmd, use_cmd_arg)
end

return M
