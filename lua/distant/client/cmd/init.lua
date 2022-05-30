return {
    --- @type fun(subcommand:string|nil):ActionCmd
    action = function(...)
        local Cmd = require('distant.client.cmd.action')
        return Cmd:new(...)
    end,

    --- @type fun(host:string):LaunchCmd
    launch = function(...)
        local Cmd = require('distant.client.cmd.launch')
        return Cmd:new(...)
    end,

    --- @type fun():ListenCmd
    listen = function()
        local Cmd = require('distant.client.cmd.listen')
        return Cmd:new()
    end,

    --- @type fun(cmd:string):LspCmd
    lsp = function(...)
        local Cmd = require('distant.client.cmd.lsp')
        return Cmd:new(...)
    end,

    --- @type fun(cmd:string|nil):ShellCmd
    shell = function(...)
        local Cmd = require('distant.client.cmd.shell')
        return Cmd:new(...)
    end,
}
