local plugin = require('distant')
local utils = require('distant.commands.utils')

--- DistantOpen path [opt1=... opt2=...]
--- @param cmd NvimCommand
local function command(cmd)
    local input = utils.parse_args(cmd.args)
    utils.paths_to_number(input.opts, { 'buf', 'win' })
    local opts = input.opts

    local path = input.args[1]

    -- If given nothing as the path, we want to replace it with current directory
    --
    -- The '.' signifies the current directory both on Unix and Windows
    if path == nil or vim.trim(path):len() == 0 then
        path = '.'
    end

    -- Update our options with the path
    opts.path = path

    -- TODO: Support bang! to force-reload a file, and
    --       by default not reload it if there are
    --       unsaved changes
    plugin.editor.open(opts)
end

--- @type DistantCommand
local COMMAND = {
    name        = 'DistantOpen',
    description = 'Open a file or directory on the remote machine',
    command     = command,
    bang        = true,
    nargs       = '*',
}
return COMMAND
