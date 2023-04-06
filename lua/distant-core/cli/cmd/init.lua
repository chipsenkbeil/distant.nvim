--- @class ClientCmd
--- @field action fun(subcommand:string|BaseCmd|nil):ClientActionCmd
--- @field action_cmd {spawn:fun(cmd:string):ProcSpawnCmd}
--- @field connect fun(destination:string):ClientConnectCmd
--- @field launch fun(destination:string):ClientLaunchCmd
--- @field lsp fun(cmd:string):ClientLspCmd
--- @field repl fun():ClientReplCmd
--- @field select fun(cmd:string|nil):ClientSelectCmd
--- @field shell fun(cmd:string|nil):ClientShellCmd

--- @class ManagerCmd
--- @field list fun():ManagerListCmd
--- @field listen fun():ManagerListenCmd

--- @class ServerCmd
--- @field listen fun():ServerListenCmd

return {
    --- @type ClientCmd
    --- For commands like `distant client ...`
    client = {
        --- @type fun(subcommand:string|nil):ClientActionCmd
        action = function(...)
            local Cmd = require('distant-core.cli.cmd.client.action')
            return Cmd:new(...)
        end,
        action_cmd = {
            --- @type fun(cmd:string|nil):ProcSpawnCmd
            spawn = function(...)
                local Cmd = require('distant-core.cli.cmd.client.spawn')
                return Cmd:new(...)
            end,
        },
        --- @type fun(destination:string):ClientConnectCmd
        connect = function(...)
            local Cmd = require('distant-core.cli.cmd.client.connect')
            return Cmd:new(...)
        end,
        --- @type fun(destination:string):ClientLaunchCmd
        launch = function(...)
            local Cmd = require('distant-core.cli.cmd.client.launch')
            return Cmd:new(...)
        end,
        --- @type fun(cmd:string):ClientLspCmd
        lsp = function(...)
            local Cmd = require('distant-core.cli.cmd.client.lsp')
            return Cmd:new(...)
        end,
        --- @type fun():ClientReplCmd
        repl = function()
            local Cmd = require('distant-core.cli.cmd.client.repl')
            return Cmd:new()
        end,
        --- @type fun(connection:string|nil):ClientSelectCmd
        select = function(...)
            local Cmd = require('distant-core.cli.cmd.client.select')
            return Cmd:new(...)
        end,
        --- @type fun(cmd:string|nil):ClientShellCmd
        shell = function(...)
            local Cmd = require('distant-core.cli.cmd.client.shell')
            return Cmd:new(...)
        end,
    },
    --- @type ManagerCmd
    --- For commands like `distant manager ...`
    manager = {
        --- @type fun():ManagerListCmd
        list = function()
            local Cmd = require('distant-core.cli.cmd.manager.list')
            return Cmd:new()
        end,
        --- @type fun():ManagerListenCmd
        listen = function()
            local Cmd = require('distant-core.cli.cmd.manager.listen')
            return Cmd:new()
        end,
    },
    --- @type ServerCmd
    --- For commands like `distant server ...`
    server = {
        --- @type fun():ServerListenCmd
        listen = function()
            local Cmd = require('distant-core.cli.cmd.server.listen')
            return Cmd:new()
        end,
    },
}
