local pickers = require('telescope.pickers')
local DistantFinder = require('telescope._extensions.distant.finder')

--- @class telescope.distant.Extension
local M = {}

function M.search(opts)
    opts = opts or {}

    pickers.new(opts, {
        prompt_title = 'distant search',
        debounce = 100,
        finder = DistantFinder:new({
            query = {
                paths = opts.paths,
                target = opts.target,
                condition = { type = 'regex' },
                options = {
                    limit = opts.limit,
                    pagination = opts.pagination,
                },
            },
            settings = {
                minimum_len = 3,
            },
        }),
    }):find()
end

M.pickers = {
    search = M.search,
}

return M
