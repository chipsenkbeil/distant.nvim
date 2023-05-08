local editor = require('distant.editor')
local utils = require('distant.commands.utils')

--- DistantSearch pattern [paths ...] [opt1=... opt2=...]
--- @param cmd NvimCommand
local function command(cmd)
    local input = utils.parse_args(cmd.args)
    utils.paths_to_number(input.opts, { 'pagination', 'limit', 'max_depth', 'timeout', 'interval' })
    utils.paths_to_bool(input.opts, { 'follow_symbolic_links' })

    local timeout = tonumber(input.opts.timeout)
    local interval = tonumber(input.opts.interval)

    local pattern = input.args[1]
    local paths = {}
    for i, path in ipairs(input.args) do
        if i > 1 then
            table.insert(paths, path)
        end
    end
    local target = input.opts.target or 'contents'
    local options = {}
    for key, value in pairs(input.opts or {}) do
        if key ~= 'timeout' and key ~= 'interval' and key ~= 'target' then
            options[key] = value
        end
    end

    -- If no path provided, default to current working directory
    if vim.tbl_isempty(paths) then
        table.insert(paths, '.')
    end

    local query = {
        paths = paths,
        target = target,
        condition = {
            type = 'regex',
            value = pattern,
        },
        options = options,
    }

    editor.search({
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
