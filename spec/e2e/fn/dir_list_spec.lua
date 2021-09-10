local fn = require('distant.fn')
local Driver = require('spec.e2e.driver')

describe('fn', function()
    local driver, root

    before_each(function()
        driver = Driver:setup()

        -- TODO: This is really expensive, but plenary doesn't offer setup/teardown
        --       functions that we could use to limit this to the the entire
        --       describe block
        --
        --       Because we don't know when the last it(...) would finish, we cannot
        --       support manually creating a fixture and unloading it as it would
        --       get unloaded while other it blocks are still using it
        root = driver:new_dir_fixture({items = {
            'dir1/',
            'dir2/',
            'file1',
            'file2',
        }})
    end)

    after_each(function()
        driver:teardown()
    end)

    describe('dir_list', function()
        it('should list directory contents', function()
            local err, entries = fn.dir_list(root.path())
            assert(not err, err)
            assert.are.same(entries, {
                {path = 'dir1', file_type = 'dir', depth = 1},
                {path = 'dir2', file_type = 'dir', depth = 1},
                {path = 'file1', file_type = 'file', depth = 1},
                {path = 'file2', file_type = 'file', depth = 1},
            })
        end)
    end)
end)
