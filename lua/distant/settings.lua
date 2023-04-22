local core = require('distant-core')

local M = core.settings

--- Retrieve settings with opinionated configuration for Chip's usage
--- @return Settings @The settings to apply to any remote machine (or empty table)
M.chip_default = function()
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
    }, M.default())
end

return M
