--- @class NvimCommand
--- @field args string
--- @field fargs table
--- @field bang boolean
--- @field line1 number
--- @field line2 number
--- @field range number
--- @field count number
--- @field reg string
--- @field mods string
--- @field smods string

--- @class DistantCommand
--- @field name string
--- @field description string
--- @field aliases? string[]
--- @field command fun(cmd:NvimCommand)
---
--- @field bang? boolean
--- @field force? boolean
--- @field nargs? integer|'*'

local log      = require('distant-core').log

-------------------------------------------------------------------------------
--- INITIALIZATION
-------------------------------------------------------------------------------

--- @type DistantCommand[]
local COMMANDS = {
    require('distant.commands.distant_cmd'),
    require('distant.commands.distant_cancel_search'),
    require('distant.commands.distant_check_health'),
    require('distant.commands.distant_client_version'),
    require('distant.commands.distant_connect'),
    require('distant.commands.distant_copy'),
    require('distant.commands.distant_install'),
    require('distant.commands.distant_launch'),
    require('distant.commands.distant_metadata'),
    require('distant.commands.distant_mkdir'),
    require('distant.commands.distant_open'),
    require('distant.commands.distant_search'),
    require('distant.commands.distant_session_info'),
    require('distant.commands.distant_shell'),
    require('distant.commands.distant_spawn'),
    require('distant.commands.distant_system_info'),
    require('distant.commands.distant_remove'),
    require('distant.commands.distant_rename'),
}

local function _initialize()
    log.trace('Initializing autocmds')

    --- @param cmd DistantCommand
    local function make_cmd(cmd)
        local names = { cmd.name }
        for _, name in ipairs(cmd.aliases or {}) do
            table.insert(names, name)
        end

        for _, name in ipairs(names) do
            vim.api.nvim_create_user_command(name, cmd.command, {
                desc = cmd.description,
                bang = cmd.bang,
                nargs = cmd.nargs,
            })
        end
    end

    for _, cmd in ipairs(COMMANDS) do
        make_cmd(cmd)
    end
end

-------------------------------------------------------------------------------
--- EXPORTS
-------------------------------------------------------------------------------

local is_initialized = false
return {
    --- Configures the commands associated with this plugin.
    ---
    --- Subsequent calls will do nothing.
    initialize = function()
        if not is_initialized then
            _initialize()
            is_initialized = true
        end
    end
}
