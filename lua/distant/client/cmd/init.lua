--- @class ClientCmd
--- @field action fun(subcommand:string|nil):ClientActionCmd
--- @field connect fun(destination:string):ClientConnectCmd
--- @field launch fun(destination:string):ClientLaunchCmd
--- @field lsp fun(cmd:string):ClientLspCmd
--- @field repl fun():ClientReplCmd
--- @field shell fun(cmd:string|nil):ClientShellCmd

--- @class ManagerCmd
--- @field listen fun():ManagerListenCmd

--- @class ServerCmd
--- @field listen fun():ServerListenCmd

return {
    --- @type ClientCmd
    --- For commands like `distant client ...`
    client = {
        --- @type fun(subcommand:string|nil):ClientActionCmd
        action = function(...)
            local Cmd = require('distant.client.cmd.client.action')
            return Cmd:new(...)
        end,

        --- @type fun(destination:string):ClientConnectCmd
        connect = function(...)
            local Cmd = require('distant.client.cmd.client.connect')
            return Cmd:new(...)
        end,

        --- @type fun(destination:string):ClientLaunchCmd
        launch = function(...)
            local Cmd = require('distant.client.cmd.client.launch')
            return Cmd:new(...)
        end,

        --- @type fun(cmd:string):ClientLspCmd
        lsp = function(...)
            local Cmd = require('distant.client.cmd.client.lsp')
            return Cmd:new(...)
        end,

        --- @type fun(cmd:string|nil):ClientReplCmd
        repl = function()
            local Cmd = require('distant.client.cmd.client.repl')
            return Cmd:new()
        end,

        --- @type fun(cmd:string|nil):ClientShellCmd
        shell = function(...)
            local Cmd = require('distant.client.cmd.client.shell')
            return Cmd:new(...)
        end,
    },

    --- @type ManagerCmd
    --- For commands like `distant manager ...`
    manager = {
        --- @type fun():ManagerListenCmd
        listen = function()
            local Cmd = require('distant.client.cmd.manager.listen')
            return Cmd:new()
        end,
    },

    --- @type ServerCmd
    --- For commands like `distant server ...`
    server = {
        --- @type fun():ServerListenCmd
        listen = function()
            local Cmd = require('distant.client.cmd.server.listen')
            return Cmd:new()
        end,
    },
}
