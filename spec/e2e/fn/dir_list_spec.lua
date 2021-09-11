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
            'dir/',
            'dir/dir2/',
            'dir/dir2/file3',
            'dir/file2',
            'file',
            -- link -> file
            {'link', 'file'},
        }})
    end)

    after_each(function()
        driver:teardown()
    end)

    describe('dir_list', function()
        it('should list immediate directory contents', function()
            local err, entries = fn.dir_list(root.path())
            assert(not err, err)
            assert.are.same(entries, {
                {path = 'dir', file_type = 'dir', depth = 1},
                {path = 'file', file_type = 'file', depth = 1},
                {path = 'link', file_type = 'symlink', depth = 1},
            })
        end)

        it('should support infinite depth if specified', function()
            local err, entries = fn.dir_list(root.path(), {depth = 0})
            assert(not err, err)
            assert.are.same(entries, {
                {path = 'dir', file_type = 'dir', depth = 1},
                {path = 'dir/dir2', file_type = 'dir', depth = 2},
                {path = 'dir/dir2/file3', file_type = 'file', depth = 3},
                {path = 'dir/file2', file_type = 'file', depth = 2},
                {path = 'file', file_type = 'file', depth = 1},
                {path = 'link', file_type = 'symlink', depth = 1},
            })
        end)

        it('should support explicit depth beyond immediate if specified', function()
            local err, entries = fn.dir_list(root.path(), {depth = 2})
            assert(not err, err)
            assert.are.same(entries, {
                {path = 'dir', file_type = 'dir', depth = 1},
                {path = 'dir/dir2', file_type = 'dir', depth = 2},
                {path = 'dir/file2', file_type = 'file', depth = 2},
                {path = 'file', file_type = 'file', depth = 1},
                {path = 'link', file_type = 'symlink', depth = 1},
            })
        end)

        it('should support absolute paths if specified', function()
            local err, entries = fn.dir_list(root.path(), {absolute = true})
            assert(not err, err)
            assert.are.same(entries, {
                {path = root.dir('dir').path(), file_type = 'dir', depth = 1},
                {path = root.file('file').path(), file_type = 'file', depth = 1},
                {path = root.symlink('link').path(), file_type = 'symlink', depth = 1},
            })
        end)

        it('should support canonicalized paths if specified', function()
            local err, entries = fn.dir_list(root.path(), {canonicalize = true})
            assert(not err, err)
            assert.are.same(entries, {
                {path = 'dir', file_type = 'dir', depth = 1},
                {path = 'file', file_type = 'file', depth = 1},
                -- Symlink gets resolved to file's path
                {path = 'file', file_type = 'symlink', depth = 1},
            })
        end)

        it('should include root path if specified', function()
            local err, entries = fn.dir_list(root.path(), {include_root = true})
            assert(not err, err)
            assert.are.same(entries, {
                {path = root.path(), file_type = 'dir', depth = 0},
                {path = 'dir', file_type = 'dir', depth = 1},
                {path = 'file', file_type = 'file', depth = 1},
                {path = 'link', file_type = 'symlink', depth = 1},
            })
        end)
    end)
end)
