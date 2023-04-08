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

    describe('search', function()
        it('should return a searcher that contains matches when synchronously searching', function()
            local err, searcher = fn.search({
                query = {
                    paths = { root.path() },
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

            -- Sort by path so we can guarantee test order
            table.sort(searcher.matches, function(a, b) return a.path < b.path end)

            -- Once done, searcher will have its matches populated
            assert.are.same({
                {
                    type = 'path',
                    path = root.path(),
                    submatches = { {
                        match = { type = 'text', value = root.path() },
                        start = 0,
                        ['end'] = string.len(root.path())
                    } },
                },
                {
                    type = 'path',
                    path = root.dir('dir').path(),
                    submatches = { {
                        match = { type = 'text', value = root.dir('dir').path() },
                        start = 0,
                        ['end'] = string.len(root.dir('dir').path())
                    } },
                },
                {
                    type = 'path',
                    path = root.dir('dir').dir('dir2').path(),
                    submatches = { {
                        match = { type = 'text', value = root.dir('dir').dir('dir2').path() },
                        start = 0,
                        ['end'] = string.len(root.dir('dir').dir('dir2').path())
                    } },
                },
                {
                    type = 'path',
                    path = root.dir('dir').dir('dir2').file('file3').path(),
                    submatches = { {
                        match = { type = 'text', value = root.dir('dir').dir('dir2').file('file3').path() },
                        start = 0,
                        ['end'] = string.len(root.dir('dir').dir('dir2').file('file3').path())
                    } },
                },
                {
                    type = 'path',
                    path = root.dir('dir').file('file2').path(),
                    submatches = { {
                        match = { type = 'text', value = root.dir('dir').file('file2').path() },
                        start = 0,
                        ['end'] = string.len(root.dir('dir').file('file2').path())
                    } },
                },
                {
                    type = 'path',
                    path = root.file('file').path(),
                    submatches = { {
                        match = { type = 'text', value = root.file('file').path() },
                        start = 0,
                        ['end'] = string.len(root.file('file').path())
                    } },
                },
                {
                    type = 'path',
                    path = root.symlink('link').path(),
                    submatches = { {
                        match = { type = 'text', value = root.symlink('link').path() },
                        start = 0,
                        ['end'] = string.len(root.symlink('link').path())
                    } },
                },
            }, searcher.matches)
        end)

        it('should support on_results callback that will capture matches via pagination', function()
            local matches = {}
            local on_results_cnt = 0

            local err, searcher = fn.search({
                query = {
                    paths = { root.path() },
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
            assert(not err, err)

            -- Sort by path so we can guarantee test order
            table.sort(matches, function(a, b) return a.path < b.path end)

            assert.is.truthy(searcher)
            assert.is.truthy(searcher.id)

            local ok = vim.wait(1000, function() return #matches == 2 end, 100)
            assert.is.truthy(ok)

            -- Should trigger on_results twice since pagination = 1 and two matches
            assert.are.equal(2, on_results_cnt)
            assert.are.same({
                {
                    type = 'path',
                    path = root.dir('dir').dir('dir2').path(),
                    submatches = { {
                        match = { type = 'text', value = 'dir2' },
                        start = string.len(root.dir('dir').path()) + 1,
                        ['end'] = string.len(root.dir('dir').path()) + 1 + string.len('dir2'),
                    } },
                },
                {
                    type = 'path',
                    path = root.dir('dir').dir('dir2').file('file3').path(),
                    submatches = { {
                        match = { type = 'text', value = 'dir2' },
                        start = string.len(root.dir('dir').path()) + 1,
                        ['end'] = string.len(root.dir('dir').path()) + 1 + string.len('dir2'),
                    } },
                },
            }, matches)
        end)

        it('should support on_done callback that will trigger with no matches if on_results also provided', function()
            local matches = {}
            local on_results_cnt = 0
            local on_done_triggered = false

            local err, searcher = fn.search({
                query = {
                    paths = { root.path() },
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
                on_done = function(mm)
                    assert(vim.tbl_isempty(mm), 'on_done got matches unexpectedly')
                    on_done_triggered = true
                end,
            })
            assert(not err, err)

            -- Sort by path so we can guarantee test order
            table.sort(matches, function(a, b) return a.path < b.path end)

            assert.is.truthy(searcher)
            assert.is.truthy(searcher.id)

            local ok = vim.wait(1000, function() return searcher.done end, 100)
            assert.is.truthy(ok)
            assert.is.truthy(on_done_triggered)
            assert.are.equal(2, on_results_cnt)
            assert.are.equal(3, #matches)
            assert.are.same({
                {
                    type = 'path',
                    path = root.file('file').path(),
                    submatches = { {
                        match = { type = 'text', value = 'file' },
                        start = string.len(root.path()) + 1,
                        ['end'] = string.len(root.path()) + 1 + string.len('file'),
                    } },
                },
                {
                    type = 'path',
                    path = root.dir('dir').dir('dir2').file('file3').path(),
                    submatches = { {
                        match = { type = 'text', value = 'file' },
                        start = string.len(root.dir('dir').dir('dir2').path()) + 1,
                        ['end'] = string.len(root.dir('dir').dir('dir2').path()) + 1 + string.len('file'),
                    } },
                },
                {
                    type = 'path',
                    path = root.dir('dir').file('file2').path(),
                    submatches = { {
                        match = { type = 'text', value = 'file' },
                        start = string.len(root.dir('dir').path()) + 1,
                        ['end'] = string.len(root.dir('dir').path()) + 1 + string.len('file'),
                    } },
                },
            }, matches)
        end)

        it('should support on_done callback that will trigger with all matches if on_results not provided', function()
            local matches = {}

            local err, searcher = fn.search({
                query = {
                    paths = { root.path() },
                    target = 'path',
                    condition = {
                        type = 'regex',
                        value = 'file',
                    },
                },
                on_done = function(mm)
                    for _, m in ipairs(mm) do
                        table.insert(matches, m)
                    end
                end,
            })
            assert(not err, err)

            -- Sort by path so we can guarantee test order
            table.sort(matches, function(a, b) return a.path < b.path end)

            assert.is.truthy(searcher)
            assert.is.truthy(searcher.id)

            local ok = vim.wait(1000, function() return searcher.done end, 100)
            assert.is.truthy(ok)
            assert.are.equal(3, #matches)
            assert.are.same({
                {
                    type = 'path',
                    path = root.file('file').path(),
                    submatches = { {
                        match = { type = 'text', value = 'file' },
                        start = string.len(root.path()) + 1,
                        ['end'] = string.len(root.path()) + 1 + string.len('file'),
                    } },
                },
                {
                    type = 'path',
                    path = root.dir('dir').dir('dir2').file('file3').path(),
                    submatches = { {
                        match = { type = 'text', value = 'file' },
                        start = string.len(root.dir('dir').dir('dir2').path()) + 1,
                        ['end'] = string.len(root.dir('dir').dir('dir2').path()) + 1 + string.len('file'),
                    } },
                },
                {
                    type = 'path',
                    path = root.dir('dir').file('file2').path(),
                    submatches = { {
                        match = { type = 'text', value = 'file' },
                        start = string.len(root.dir('dir').path()) + 1,
                        ['end'] = string.len(root.dir('dir').path()) + 1 + string.len('file'),
                    } },
                },
            }, searcher.matches)
        end)
    end)
end)
