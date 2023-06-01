local plugin = require('distant')
local utils  = require('distant.commands.utils')

--- DistantInstall [reinstall]
--- @param cmd NvimCommand
local function command(cmd)
    local input = utils.parse_args(cmd.args)
    local reinstall = cmd.bang or input.args[1] == 'reinstall'

    plugin:cli():install({
        min_version = plugin.version.cli.min,
        reinstall = reinstall,
    }, function(err, path)
        assert(not err, tostring(err))
        assert(path, 'Cli not installed')
        vim.notify('Installed to ' .. path)
    end)
end

--- @type DistantCommand
local COMMAND = {
    name        = 'DistantInstall',
    description = 'Installs the distant CLI locally',
    command     = command,
    bang        = true,
    nargs       = '*',
}
return COMMAND
