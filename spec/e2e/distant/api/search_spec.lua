local plugin = require('distant')
local Driver = require('spec.e2e.driver')

describe('distant.api.search', function()
    --- @type spec.e2e.Driver, spec.e2e.RemoteDir
    local driver, root

    before_each(function()
        driver = Driver:setup({ label = 'distant.api.search' })

        -- TODO: This is really expensive, but plenary doesn't offer setup/teardown
        --       functions that we could use to limit this to the the entire
        --       describe block
        --
        --       Because we don't know when the last it(...) would finish, we cannot
        --       support manually creating a fixture and unloading it as it would
        --       get unloaded while other it blocks are still using it
        root = driver:new_dir_fixture({
            items = {
                'dir/',
                'dir/dir2/',
                'dir/dir2/file3',
                'dir/file2',
                'file',
                -- link -> file
                { 'link', 'file' },
            }
        })
    end)

    after_each(function()
        driver:teardown()
    end)

    describe('synchronous', function()
        it('should return all matches when run synchronously', function()
            --- @type distant.core.api.Error|nil, distant.core.api.search.Match[]|nil
            local err, matches = plugin.api.search({
                query = {
                    paths = { root:path() },
                    target = 'path',
                    condition = {
                        type = 'regex',
                        value = '.*',
                    },
                },
            })
            assert(not err, tostring(err))
            assert(matches)

            -- Sort by path so we can guarantee test order
            table.sort(matches, function(a, b) return a.path < b.path end)

            -- Once done, searcher will have its matches populated
            assert.are.same({
                {
                    type = 'path',
                    path = root:path(),
                    submatches = { {
                        match = root:path(),
                        start = 0,
                        ['end'] = string.len(root:path())
                    } },
                },
                {
                    type = 'path',
                    path = root:dir('dir'):path(),
                    submatches = { {
                        match = root:dir('dir'):path(),
                        start = 0,
                        ['end'] = string.len(root:dir('dir'):path())
                    } },
                },
                {
                    type = 'path',
                    path = root:dir('dir'):dir('dir2'):path(),
                    submatches = { {
                        match = root:dir('dir'):dir('dir2'):path(),
                        start = 0,
                        ['end'] = string.len(root:dir('dir'):dir('dir2'):path())
                    } },
                },
                {
                    type = 'path',
                    path = root:dir('dir'):dir('dir2'):file('file3'):path(),
                    submatches = { {
                        match = root:dir('dir'):dir('dir2'):file('file3'):path(),
                        start = 0,
                        ['end'] = string.len(root:dir('dir'):dir('dir2'):file('file3'):path())
                    } },
                },
                {
                    type = 'path',
                    path = root:dir('dir'):file('file2'):path(),
                    submatches = { {
                        match = root:dir('dir'):file('file2'):path(),
                        start = 0,
                        ['end'] = string.len(root:dir('dir'):file('file2'):path())
                    } },
                },
                {
                    type = 'path',
                    path = root:file('file'):path(),
                    submatches = { {
                        match = root:file('file'):path(),
                        start = 0,
                        ['end'] = string.len(root:file('file'):path())
                    } },
                },
                {
                    type = 'path',
                    path = root:symlink('link'):path(),
                    submatches = { {
                        match = root:symlink('link'):path(),
                        start = 0,
                        ['end'] = string.len(root:symlink('link'):path())
                    } },
                },
            }, matches)
        end)

        it('should support on_results callback that will capture matches via pagination', function()
            --- @type distant.core.api.search.Match[]
            local matches = {}
            local on_results_cnt = 0

            -- NOTE: Without a callback as second argument, we still wait to complete
            --       our search, but the on_results callback will be invoked. This means
            --       that an empty set of matches will be provided at the end!
            --- @type distant.core.api.Error|nil, distant.core.api.search.Match[]|nil
            local err, done_matches = plugin.api.search({
                query = {
                    paths = { root:path() },
                    target = 'path',
                    condition = {
                        type = 'regex',
                        value = 'dir2',
                    },
                    options = { pagination = 1 },
                },
                on_results = function(mm)
                    for _, m in ipairs(mm) do
                        table.insert(matches, m)
                    end
                    on_results_cnt = on_results_cnt + 1
                end,
            })
            assert(not err, tostring(err))
            assert(done_matches)

            -- Verify that the done matches is an empty list
            assert.are.equal(0, #done_matches)

            -- Sort by path so we can guarantee test order
            table.sort(matches, function(a, b) return a.path < b.path end)

            -- Should trigger on_results twice since pagination = 1 and two matches
            assert.are.equal(2, on_results_cnt)
            assert.are.same({
                {
                    type = 'path',
                    path = root:dir('dir'):dir('dir2'):path(),
                    submatches = { {
                        match = 'dir2',
                        start = string.len(root:dir('dir'):path()) + 1,
                        ['end'] = string.len(root:dir('dir'):path()) + 1 + string.len('dir2'),
                    } },
                },
                {
                    type = 'path',
                    path = root:dir('dir'):dir('dir2'):file('file3'):path(),
                    submatches = { {
                        match = 'dir2',
                        start = string.len(root:dir('dir'):path()) + 1,
                        ['end'] = string.len(root:dir('dir'):path()) + 1 + string.len('dir2'),
                    } },
                },
            }, matches)
        end)
    end)

    describe('asynchronous', function()
        it('should support callback that will trigger with no matches if on_results also provided', function()
            --- @type distant.core.api.search.Match[]
            local matches = {}
            local on_results_cnt = 0
            local cb_triggered = false

            --- @type distant.core.api.Error|nil, distant.core.api.Searcher|nil
            local err, searcher = plugin.api.search({
                query = {
                    paths = { root:path() },
                    target = 'path',
                    condition = {
                        type = 'regex',
                        value = 'file',
                    },
                    options = { pagination = 2 },
                },
                on_results = function(mm)
                    for _, m in ipairs(mm) do
                        table.insert(matches, m)
                    end
                    on_results_cnt = on_results_cnt + 1
                end,
            }, function(err, mm)
                assert(not err, tostring(err))
                assert(vim.tbl_isempty(mm), 'cb got matches unexpectedly')
                cb_triggered = true
            end)
            assert(not err, tostring(err))
            assert(searcher)

            assert.is.truthy(searcher)
            assert.is.truthy(searcher.id)

            -- Wait for the search to finish
            local ok = vim.wait(1000, function() return searcher:is_done() end, 100)

            -- Sort by path so we can guarantee test order
            table.sort(matches, function(a, b) return a.path < b.path end)

            assert.is.truthy(ok)
            assert.is.truthy(cb_triggered)
            assert.are.equal(2, on_results_cnt)
            assert.are.equal(3, #matches)
            assert.are.same({
                {
                    type = 'path',
                    path = root:dir('dir'):dir('dir2'):file('file3'):path(),
                    submatches = { {
                        match = 'file',
                        start = string.len(root:dir('dir'):dir('dir2'):path()) + 1,
                        ['end'] = string.len(root:dir('dir'):dir('dir2'):path()) + 1 + string.len('file'),
                    } },
                },
                {
                    type = 'path',
                    path = root:dir('dir'):file('file2'):path(),
                    submatches = { {
                        match = 'file',
                        start = string.len(root:dir('dir'):path()) + 1,
                        ['end'] = string.len(root:dir('dir'):path()) + 1 + string.len('file'),
                    } },
                },
                {
                    type = 'path',
                    path = root:file('file'):path(),
                    submatches = { {
                        match = 'file',
                        start = string.len(root:path()) + 1,
                        ['end'] = string.len(root:path()) + 1 + string.len('file'),
                    } },
                },
            }, matches)
        end)

        it('should support callback that will trigger with all matches if on_results not provided', function()
            --- @type distant.core.api.search.Match[]
            local matches = {}

            --- @type distant.core.api.Error|nil, distant.core.api.Searcher|nil
            local err, searcher = plugin.api.search({
                query = {
                    paths = { root:path() },
                    target = 'path',
                    condition = {
                        type = 'regex',
                        value = 'file',
                    },
                }
            }, function(err, mm)
                assert(not err, tostring(err))
                for _, m in ipairs(mm) do
                    table.insert(matches, m)
                end
            end)
            assert(not err, tostring(err))
            assert(searcher)

            -- Wait for the search to finish
            local ok = vim.wait(1000, function() return searcher:is_done() end, 100)

            -- Sort by path so we can guarantee test order
            table.sort(matches, function(a, b) return a.path < b.path end)

            assert.is.truthy(ok)
            assert.are.equal(3, #matches)
            assert.are.same({
                {
                    type = 'path',
                    path = root:dir('dir'):dir('dir2'):file('file3'):path(),
                    submatches = { {
                        match = 'file',
                        start = string.len(root:dir('dir'):dir('dir2'):path()) + 1,
                        ['end'] = string.len(root:dir('dir'):dir('dir2'):path()) + 1 + string.len('file'),
                    } },
                },
                {
                    type = 'path',
                    path = root:dir('dir'):file('file2'):path(),
                    submatches = { {
                        match = 'file',
                        start = string.len(root:dir('dir'):path()) + 1,
                        ['end'] = string.len(root:dir('dir'):path()) + 1 + string.len('file'),
                    } },
                },
                {
                    type = 'path',
                    path = root:file('file'):path(),
                    submatches = { {
                        match = 'file',
                        start = string.len(root:path()) + 1,
                        ['end'] = string.len(root:path()) + 1 + string.len('file'),
                    } },
                },
            }, matches)
        end)
    end)
end)
