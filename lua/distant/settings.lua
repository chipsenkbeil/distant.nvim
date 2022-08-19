local log = require('distant.log')
local utils = require('distant.utils')

--- @class Settings
--- @field client ClientSettings
--- @field max_timeout number
--- @field timeout_interval number
--- @field file FileSettings
--- @field dir DirSettings
--- @field lsp table<string, LspSettings>

--- @class ClientSettings
--- @field bin string

--- @class FileSettings
--- @field mappings table<string, fun()>

--- @class DirSettings
--- @field mappings table<string, fun()>

--- @class LspSettings
--- @field root_dir string
--- @field filetypes? string[]
--- @field on_exit? fun(code:number, signal:number|nil, client_id:string)
--- @field opts? table

-- Represents the label used to signify default/global settings
local DEFAULT_LABEL = '*'

--- Default settings to apply to any-and-all servers
--- @type Settings
local DEFAULT_SETTINGS = {
    -- Settings to apply to the local distant binary used as a client
    client = {
        -- Will be filled in lazily
        --- @type 'distant'|'distant.exe'
        bin = nil,
    },

    -- Maximimum time to wait (in milliseconds) for requests to finish
    max_timeout = 15 * 1000,

    -- Time to wait (in milliseconds) inbetween checks to see
    -- if a request timed out
    timeout_interval = 250,

    -- Settings that apply when editing a remote file
    file = {
        -- Mappings to apply to remote files
        mappings = {};
    };

    -- Settings that apply to the navigation interface
    dir = {
        -- Mappings to apply to the navigation interface
        mappings = {};
    };

    -- Settings to use to start LSP instances
    --- @type LspSettings
    lsp = {};
}

local settings = {}

--- Contains the setting definitions for all remote machines, each
--- associated by a label with '*' representing a blanket set of
--- settings to apply first before adding in server-specific settings
---
--- @type table<string, Settings>
local inner = { [DEFAULT_LABEL] = vim.tbl_deep_extend('force', {}, DEFAULT_SETTINGS) }

--- Merges current settings with provided, overwritting anything with provided
--- @param other table<string, Settings> The other settings to include
settings.merge = function(other)
    inner = vim.tbl_deep_extend('force', inner, other)
end

--- Returns a collection of labels contained by the settings
--- @param exclude_default? boolean If true, will not include default label in results
--- @return string[]
settings.labels = function(exclude_default)
    local labels = {}
    for label, _ in pairs(inner) do
        if not exclude_default or label ~= DEFAULT_LABEL then
            table.insert(labels, label)
        end
    end
    return labels
end

--- Retrieve settings for a specific remote machine defined by a label, also
--- applying any default settings
--- @param label string The label associated with the remote server's settings
--- @param no_default? boolean If true, will not apply default settings first
--- @return Settings @The settings associated with the remote machine (or empty table)
settings.for_label = function(label, no_default)
    log.fmt_trace('settings.for_label(%s, %s)', label, vim.inspect(no_default))

    local specific = inner[label] or {}
    local default = settings.default()

    local settings_for_label = specific
    if not no_default then
        settings_for_label = vim.tbl_deep_extend('force', default, specific)
    end

    return settings_for_label
end

--- Retrieves settings that apply to any remote machine
--- @return Settings @The settings to apply to any remote machine (or empty table)
settings.default = function()
    local tbl = inner[DEFAULT_LABEL] or {}

    -- Lazily determine the default binary if not configured
    if not tbl.client.bin then
        local os_name = utils.detect_os_arch()
        tbl.client.bin = os_name == 'windows' and
            'distant.exe' or
            'distant'
    end

    return tbl
end

--- Retrieve settings with opinionated configuration for Chip's usage
--- @return Settings @The settings to apply to any remote machine (or empty table)
settings.chip_default = function()
    local actions = require('distant.nav.actions')

    return vim.tbl_deep_extend('keep', {
        distant = {
            args = { '--shutdown', 'lonely=60' },
        },
        file = {
            mappings = {
                ['-'] = actions.up,
            },
        },
        dir = {
            mappings = {
                ['<Return>'] = actions.edit,
                ['-']        = actions.up,
                ['K']        = actions.mkdir,
                ['N']        = actions.newfile,
                ['R']        = actions.rename,
                ['D']        = actions.remove,
            }
        },
    }, settings.default())
end

return settings
