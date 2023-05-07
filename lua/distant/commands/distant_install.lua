local Cli         = require('distant-core.cli')
local min_version = require('distant.version').minimum
local state       = require('distant.state')
local utils       = require('distant.commands.utils')

--- DistantInstall [reinstall]
--- @param cmd NvimCommand
local function command(cmd)
    local input = utils.parse_input(cmd.args)
    local reinstall = cmd.bang or input.args[1] == 'reinstall'

    Cli:new({ bin = state:path_to_cli() }):install({
        min_version = min_version,
        reinstall = reinstall,
    }, function(err, path)
        assert(not err, err)
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
