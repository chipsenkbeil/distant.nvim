local editor = require('distant.editor')
local Driver = require('spec.e2e.driver')

describe('distant.editor.search', function()
    --- @type spec.e2e.Driver, spec.e2e.RemoteDir
    local driver, root

    before_each(function()
        driver = Driver:setup({
            label = 'distant.editor.search',

            -- Disable watching buffer content changes for our tests
            settings = {
                buffer = {
                    watch = {
                        enabled = false
                    }
                }
            },
        })
        root = driver:new_dir_fixture()
    end)

    after_each(function()
        -- Will remove all fixtures
        driver:teardown()
    end)

    --- @param items neovim.qflist.Item[]
    --- @return table<string, neovim.qflist.Item>
    local function to_tbl(items)
        local tbl = {}

        for _, item in ipairs(items) do
            tbl[item.module] = item
        end

        return tbl
    end

    it('should populate a quickfix list with results as they appear', function()
        -- Create some files with content to search
        local file_1 = root:file('file1.txt')
        file_1:write('aaa 123')

        local file_2 = root:file('file2.txt')
        file_2:write('bbb 456')

        local dir_1 = root:dir('dir1')
        dir_1:make()

        local dir_1_file_1 = dir_1:file('file1.txt')
        dir_1_file_1:write('ccc 789')

        -- Start the search using a regex query
        local matches
        editor.search({
            query = {
                paths = { root:path() },
                target = 'contents',
                condition = {
                    type = 'regex',
                    value = '[bc]',
                },
            },
        }, function(err, mm)
            assert(not err, tostring(err))
            matches = mm
        end)

        -- Wait for search to finish
        local time = 1000 * 5
        assert(
            vim.wait(time, function() return matches ~= nil end),
            string.format('Search did not finish after %.2fs', time / 1000.0)
        )

        -- Verify the quickfix list is populated accordingly
        local items = to_tbl(vim.fn.getqflist())

        -- NOTE: The order in which these items get populated will dictate
        --       which bufnr is assigned. E.g. if file_2 is handled first,
        --       it would have bufnr 3, but if it was handled second, it
        --       would have bufnr 4. Because we cannot control that, we
        --       want to validate that they occupy these buffers and then
        --       delete the value so we can test everything else!
        local bufnrs = vim.tbl_map(function(item) return item.bufnr end, vim.tbl_values(items))
        table.sort(bufnrs)
        assert.are.same(bufnrs, { 3, 4 })
        for _, item in pairs(items) do
            item.bufnr = nil
        end

        -- NOTE: We make it a map with keys so we can compare
        --       regardless of the order of the items
        assert.are.same({
            [file_2:path()] = {
                col = 1,
                end_col = 1,
                end_lnum = 1,
                lnum = 1,
                module = file_2:path(),
                nr = 0,
                pattern = '',
                text = 'bbb 456',
                type = '',
                valid = 1,
                vcol = 0
            },
            [dir_1_file_1:path()] = {
                col = 1,
                end_col = 1,
                end_lnum = 1,
                lnum = 1,
                module = dir_1_file_1:path(),
                nr = 0,
                pattern = '',
                text = 'ccc 789',
                type = '',
                valid = 1,
                vcol = 0
            }
        }, items)
    end)
end)
