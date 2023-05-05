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

local log                    = require('distant-core').log

-------------------------------------------------------------------------------
--- INITIALIZATION
-------------------------------------------------------------------------------

local distant_cancel_search  = require('distant.commands.distant_cancel_search')
local distant_client_version = require('distant.commands.distant_client_version')
local distant_connect        = require('distant.commands.distant_connect')
local distant_copy           = require('distant.commands.distant_copy')
local distant_install        = require('distant.commands.distant_install')
local distant_launch         = require('distant.commands.distant_launch')
local distant_metadata       = require('distant.commands.distant_metadata')
local distant_mkdir          = require('distant.commands.distant_mkdir')
local distant_open           = require('distant.commands.distant_open')
local distant_search         = require('distant.commands.distant_search')
local distant_session_info   = require('distant.commands.distant_session_info')
local distant_shell          = require('distant.commands.distant_shell')
local distant_spawn          = require('distant.commands.distant_spawn')
local distant_system_info    = require('distant.commands.distant_system_info')
local distant_remove         = require('distant.commands.distant_remove')
local distant_rename         = require('distant.commands.distant_rename')

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

    make_cmd(distant_cancel_search)
    make_cmd(distant_client_version)
    make_cmd(distant_connect)
    make_cmd(distant_copy)
    make_cmd(distant_install)
    make_cmd(distant_launch)
    make_cmd(distant_metadata)
    make_cmd(distant_mkdir)
    make_cmd(distant_open)
    make_cmd(distant_search)
    make_cmd(distant_session_info)
    make_cmd(distant_shell)
    make_cmd(distant_spawn)
    make_cmd(distant_system_info)
    make_cmd(distant_remove)
    make_cmd(distant_rename)
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
