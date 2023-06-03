local plugin = require('distant')

--- DistantClientVersion
--- @param cmd NvimCommand
--- @diagnostic disable-next-line:unused-local
local function command(cmd)
    local version = assert(
        plugin:cli():version(),
        'Unable to retrieve version'
    )
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
