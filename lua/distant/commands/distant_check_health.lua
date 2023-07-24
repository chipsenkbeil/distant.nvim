--- DistantCheckHealth
--- @param cmd NvimCommand
--- @diagnostic disable-next-line:unused-local
local function command(cmd)
    vim.cmd([[checkhealth distant]])
end

--- @type DistantCommand
local COMMAND = {
    name        = 'DistantCheckHealth',
    description = 'Checks the health of the distant plugin',
    command     = command,
    bang        = false,
    nargs       = 0,
}
return COMMAND
