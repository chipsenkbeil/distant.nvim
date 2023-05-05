local Cli = require('distant-core.cli')

--- DistantClientVersion
--- @param cmd NvimCommand
--- @diagnostic disable-next-line:unused-local
local function command(cmd)
    -- TODO: Get binary path
    local version = assert(Cli:new({ bin = '' }):version(), 'Unable to retrieve version')
    print(version)
end

--- @type DistantCommand
local COMMAND = {
    name        = 'DistantClientVersion',
    description = 'Prints out the version of the locally-installed distant CLI',
    command     = command,
    bang        = false,
    nargs       = 0,
}
return COMMAND
