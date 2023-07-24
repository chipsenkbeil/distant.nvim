local plugin = require('distant')
local utils = require('distant.commands.utils')

--- DistantSearch pattern [path=...] [target=...] [opt1=... opt2=...]
--- @param cmd NvimCommand
local function command(cmd)
    local input = utils.parse_args(cmd.args)
    utils.paths_to_number(input.opts, {
        'pagination',
        'limit',
        'max_depth',
        'timeout',
        'interval',
    })
    utils.paths_to_bool(input.opts, {
        'follow_symbolic_links',
        'upward',
    })

    local timeout = tonumber(input.opts.timeout)
    local interval = tonumber(input.opts.interval)

    local pattern = input.args[1]
    local path = input.opts.path or '.'
    local target = input.opts.target or 'contents'
    local options = {}
    for key, value in pairs(input.opts or {}) do
        if key ~= 'timeout' and key ~= 'interval' and key ~= 'target' then
            options[key] = value
        end
    end

    local query = {
        paths = { path },
        target = target,
        condition = {
            type = 'regex',
            value = pattern,
        },
        options = options,
    }

    plugin.editor.search({
        query = query,
        timeout = timeout,
        interval = interval,
    })
end

--- @type DistantCommand
local COMMAND = {
    name        = 'DistantSearch',
    description = 'Performs a remote search, placing matches in a quick-fix list',
    command     = command,
    bang        = false,
    nargs       = '*',
}
return COMMAND
