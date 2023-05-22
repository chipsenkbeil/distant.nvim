local plugin = require('distant')
local utils = require('distant.commands.utils')

--- DistantLaunch destination [opt1=..., opt2=...]
--- @param cmd NvimCommand
local function command(cmd)
    local input = utils.parse_args(cmd.args)
    utils.paths_to_number(input.opts, { 'timeout', 'interval' })

    local destination = input.args[1]
    input.opts.destination = destination

    if type(destination) ~= 'string' then
        vim.api.nvim_err_writeln('Missing destination')
        return
    end

    plugin.editor.launch(input.opts, function(err, _)
        if not err then
            vim.notify('Connected to ' .. destination)
        else
            vim.api.nvim_err_writeln(tostring(err) or 'Launch failed without cause')
        end
    end)
end

--- @type DistantCommand
local COMMAND = {
    name        = 'DistantLaunch',
    description = 'Launches a server on a remote machine and connects to it',
    command     = command,
    bang        = false,
    nargs       = '*',
}
return COMMAND
