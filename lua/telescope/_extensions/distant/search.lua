local pickers = require('telescope.pickers')
local DistantFinder = require('telescope._extensions.distant.finder')

local M = {}

function M.search(opts)
    opts = opts or {}

    pickers.new(opts, {
        prompt_title = 'distant search',
        finder = DistantFinder:new({
            query = {
                paths = opts.paths,
                target = opts.target,
                condition = { type = 'regex' },
                options = {
                    limit = opts.limit,
                    pagination = opts.pagination,
                },
            }
        }),
    }):find()
end

return M
