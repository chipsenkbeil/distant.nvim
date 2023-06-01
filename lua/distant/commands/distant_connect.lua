local plugin = require('distant')
local utils = require('distant.commands.utils')

--- DistantConnect destination [opt1=..., opt2=...]
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

    plugin.editor.connect(input.opts, function(err)
        if not err then
            vim.notify('Connected to ' .. destination)
        else
            vim.api.nvim_err_writeln(tostring(err) or 'Connect failed without cause')
        end
    end)
end

--- @type DistantCommand
local COMMAND = {
    name        = 'DistantConnect',
    description = 'Connects to a remote server',
    command     = command,
    bang        = false,
    nargs       = '*',
}
return COMMAND
