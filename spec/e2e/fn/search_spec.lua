local fn = require('distant.fn')
local Driver = require('spec.e2e.driver')

describe('fn', function()
    local driver, root

    before_each(function()
        driver = Driver:setup({ label = 'fn.search' })

        -- TODO: This is really expensive, but plenary doesn't offer setup/teardown
        --       functions that we could use to limit this to the the entire
        --       describe block
        --
        --       Because we don't know when the last it(...) would finish, we cannot
        --       support manually creating a fixture and unloading it as it would
        --       get unloaded while other it blocks are still using it
        root = driver:new_dir_fixture({ items = {
            'dir/',
            'dir/dir2/',
            'dir/dir2/file3',
            'dir/file2',
            'file',
            -- link -> file
            { 'link', 'file' },
        } })
    end)

    after_each(function()
        driver:teardown()
    end)

    describe('search', function()
        it('should return a searcher', function()
            local err, searcher = fn.search({
                query = {
                    path = root.path(),
                    target = 'path',
                    condition = {
                        type = 'regex',
                        value = '.*',
                    },
                },
            })
            assert(not err, err)

            assert.is.truthy(searcher)
            assert.is.truthy(searcher.id)

            -- Searcher should eventually have its done flag set once the
            -- search has completed
            local ok = vim.wait(1000, function() return searcher.done end, 100)
            assert.is.truthy(ok)

            -- Once done, searcher will have its matches populated
            assert.are.same({
                type = 'path',
                matches = {
                    {
                        path = '',
                        submatches = {
                            {
                                match = '',
                                start = 0,
                                ['end'] = 1,
                            }
                        },
                    }
                },
            }, searcher.matches)
        end)

        it('should support on_match callback', function()
            local matches = {}

            local err, searcher = fn.search({
                query = {
                    path = '.',
                    target = 'path',
                    condition = {
                        type = 'regex',
                        value = 'dir2',
                    },
                },
                on_match = function()
                end,
            })
            assert(not err, err)

            assert.is.truthy(searcher)
            assert.is.truthy(searcher.id)

            local ok = vim.wait(1000, function() return #matches == 2 end, 100)
            assert.is.truthy(ok)
        end)
    end)
end)
