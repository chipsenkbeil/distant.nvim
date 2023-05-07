local nav = require('distant.nav')
local settings = require('distant-core').settings

local M = {}

--- Retrieves default settings.
--- @return distant.core.Settings
function M.default()
    return settings.default()
end

--- Retrieve settings with opinionated configuration for Chip's usage
--- @return distant.core.Settings #The settings to apply to any remote machine (or empty table)
function M.chip_default()
    return vim.tbl_deep_extend('keep', {
        distant = {
            args = { '--shutdown', 'lonely=60' },
        },
        file = {
            mappings = {
                ['-'] = nav.actions.up,
            },
        },
        dir = {
            mappings = {
                ['<Return>'] = nav.actions.edit,
                ['-']        = nav.actions.up,
                ['K']        = nav.actions.mkdir,
                ['N']        = nav.actions.newfile,
                ['R']        = nav.actions.rename,
                ['D']        = nav.actions.remove,
            }
        },
    }, M.default())
end

return M
