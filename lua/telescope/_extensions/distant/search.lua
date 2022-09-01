local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local conf = require('telescope.config').values
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')

local fn = require('distant.fn')
local log = require('distant.log')
local state = require('distant.state')

local M = {}

function M.search(opts)
    opts = opts or {}
    pickers.new(opts, {
        prompt_title = 'distant search',
        finder = finders.new_table({
            results = {},
        }),
        layout_strategy = 'bottom_pane',
        layout_config = {
            height = 1,
        },
        attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
                actions.close(prompt_bufnr)
                local selected = action_state.get_current_line()
                local search_opts = { query = selected }

                search_opts.on_results = function(matches)
                end

                search_opts.on_done = function(matches)
                end

                fn.search(search_opts, function(err, searcher)
                    assert(not err, err)

                    state.search = {
                        qfid = 0,
                        searcher = searcher,
                    }
                end)
            end)
            return true
        end,
    }):find()
end

return M
