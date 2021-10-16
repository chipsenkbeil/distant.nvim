local log = require('distant.log')
local u = require('distant.utils')

-- Represents the label used to signify default/global settings
local DEFAULT_LABEL = '*'

-- Default settings to apply to any-and-all servers
local DEFAULT_SETTINGS = {
    -- Maximimum time to wait (in milliseconds) for requests to finish
    max_timeout = 15 * 1000,

    -- Time to wait (in milliseconds) inbetween checks to see
    -- if a request timed out
    timeout_interval = 250,

    -- Time to wait (in milliseconds) inbetween polling checks to
    -- see if an async function has completed
    poll_interval = 200,

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
    lsp = {};
}

local settings = {}

-- Contains the setting definitions for all remote machines, each
-- associated by a label with '*' representing a blanket set of
-- settings to apply first before adding in server-specific settings
local inner = { [DEFAULT_LABEL] = u.merge({}, DEFAULT_SETTINGS) }

--- Merges current settings with provided, overwritting anything with provided
--- @param other table The other settings to include
settings.merge = function(other)
    inner = u.merge(inner, other)
end

--- Returns a collection of labels contained by the settings
--- @param exclude_default? boolean If true, will not include default label in results
--- @return table #A list of labels
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
--- @return table #The settings associated with the remote machine (or empty table)
settings.for_label = function(label, no_default)
    log.fmt_trace('settings.for_label(%s, %s)', label, vim.inspect(no_default))

    local specific = inner[label] or {}
    local default = settings.default()

    local settings_for_label = specific
    if not no_default then
        settings_for_label = u.merge(default, specific)
    end

    return settings_for_label
end

--- Retrieves settings that apply to any remote machine
--- @return table #The settings to apply to any remote machine (or empty table)
settings.default = function()
    return inner[DEFAULT_LABEL] or {}
end

--- Retrieve settings with opinionated configuration for Chip's usage
--- @return table #The settings to apply to any remote machine (or empty table)
settings.chip_default = function()
    local actions = require('distant.nav.actions')

    return vim.tbl_deep_extend('keep', {
        distant = {
            args = {'--shutdown-after', '60'},
        },
        file = {
          mappings = {
            ['-']         = actions.up,
          },
        },
        dir = {
          mappings = {
            ['<Return>']  = actions.edit,
            ['-']         = actions.up,
            ['K']         = actions.mkdir,
            ['N']         = actions.newfile,
            ['R']         = actions.rename,
            ['D']         = actions.remove,
          }
        },
    }, settings.default())
end

return settings
