local Destination = require('distant-core.destination')
local log = require('distant-core.log')

--- @class distant.core.SettingsManager
--- @field default {label:string, settings:table}
--- @field private __inner table<string, table>
local M = {}
M.__index = M

--- @param opts {default?:{label?:string, settings?:table}}
--- @return distant.core.SettingsManager
function M:new(opts)
    local instance = {}
    setmetatable(instance, M)
    instance.default = {
        label = opts.default and opts.default.label or '*',
        settings = opts.default and opts.default.settings or {},
    }

    --- Contains the setting definitions for all remote machines, each
    --- associated by a label with '*' representing a blanket set of
    --- settings to apply first before adding in server-specific settings
    instance.__inner = {
        [instance.default.label] = vim.deepcopy(instance.default.settings)
    }

    return instance
end

--- Merges current settings with provided, overwritting anything with provided
--- @param other table<string, table> The other settings to include
function M:merge(other)
    self.__inner = vim.tbl_deep_extend('force', self.__inner, other)
end

--- Returns a collection of labels contained by the settings
--- @param exclude_default? boolean If true, will not include default label in results
--- @return string[]
function M:labels(exclude_default)
    local labels = {}
    for label, _ in pairs(self.__inner) do
        if not exclude_default or label ~= self.default.label then
            table.insert(labels, label)
        end
    end
    return labels
end

--- Retrieve settings for a specific remote machine defined by a destination,
--- also applying any default settings.
---
--- @param destination string #Full destination to server, which can be in a form like SCHEME://USER:PASSWORD@HOST:PORT
--- @param no_default? boolean #If true, will not apply default settings first
--- @return table
function M:for_destination(destination, no_default)
    log.fmt_trace('settings.for_destination(%s, %s)', destination, vim.inspect(no_default))

    -- Parse our destination into the host only
    local label
    local d = Destination:try_parse(destination)
    if not d or not d.host then
        error('Invalid destination: ' .. tostring(destination))
    else
        label = d.host
        log.fmt_debug('Using settings label: %s', label)
    end

    return self:for_label(label, no_default)
end

--- Retrieve settings for a specific remote machine defined by a label, also
--- applying any default settings.
---
--- @param label string #The label associated with the remote server's settings
--- @param no_default? boolean #If true, will not apply default settings first
--- @return table #The settings associated with the remote machine (or empty table)
function M:for_label(label, no_default)
    log.fmt_trace('settings.for_label(%s, %s)', label, vim.inspect(no_default))

    local specific = self.__inner[label] or {}
    local default = self:default()

    local settings_for_label = specific
    if not no_default then
        settings_for_label = vim.tbl_deep_extend('force', default, specific)
    end

    return settings_for_label
end

return M
