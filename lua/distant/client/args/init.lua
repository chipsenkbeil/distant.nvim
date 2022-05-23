return {
    action = function(...)
        local Args = require('distant.args.action') 
        return Args:new(...)
    end,
    launch = function(...)
        local Args = require('distant.args.launch') 
        return Args:new(...)
    end,
    listen = function(...)
        local Args = require('distant.args.listen') 
        return Args:new(...)
    end,
    lsp = function(...)
        local Args = require('distant.args.lsp') 
        return Args:new(...)
    end,
    shell = function(...)
        local Args = require('distant.args.shell') 
        return Args:new(...)
    end,
}
