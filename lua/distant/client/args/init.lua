return {
    --- @type fun(subcommand:string|nil):ActionArgs
    action = function(...)
        local Args = require('distant.client.args.action')
        return Args:new(...)
    end,

    --- @type fun(host:string):LaunchArgs
    launch = function(...)
        local Args = require('distant.client.args.launch')
        return Args:new(...)
    end,

    --- @type fun():ListenArgs
    listen = function()
        local Args = require('distant.client.args.listen')
        return Args:new()
    end,

    --- @type fun(cmd:string):LspArgs
    lsp = function(...)
        local Args = require('distant.client.args.lsp')
        return Args:new(...)
    end,

    --- @type fun(cmd:string|nil):ShellArgs
    shell = function(...)
        local Args = require('distant.client.args.shell')
        return Args:new(...)
    end,
}
