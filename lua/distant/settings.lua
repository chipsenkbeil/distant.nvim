local nav = require('distant.nav')
local settings = require('distant-core').settings

local M = {}

--- Retrieve settings with opinionated configuration for Chip's usage
--- @return DistantSettings @The settings to apply to any remote machine (or empty table)
M.chip_default = function()
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
    }, settings.default())
end

return M
