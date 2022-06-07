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

    describe('read_dir', function()
        it('should list immediate directory contents', function()
            local err, res = fn.read_dir({ path = root.path() })
            assert(not err, err)
            assert.are.same(res.entries, {
                { path = 'dir', file_type = 'dir', depth = 1 },
                { path = 'file', file_type = 'file', depth = 1 },
                { path = 'link', file_type = 'symlink', depth = 1 },
            })
        end)

        it('should support infinite depth if specified', function()
            local err, res = fn.read_dir({ path = root.path(), depth = 0 })
            assert(not err, err)
            assert.are.same(res.entries, {
                { path = 'dir', file_type = 'dir', depth = 1 },
                { path = 'dir/dir2', file_type = 'dir', depth = 2 },
                { path = 'dir/dir2/file3', file_type = 'file', depth = 3 },
                { path = 'dir/file2', file_type = 'file', depth = 2 },
                { path = 'file', file_type = 'file', depth = 1 },
                { path = 'link', file_type = 'symlink', depth = 1 },
            })
        end)

        it('should support explicit depth beyond immediate if specified', function()
            local err, res = fn.read_dir({ path = root.path(), depth = 2 })
            assert(not err, err)
            assert.are.same(res.entries, {
                { path = 'dir', file_type = 'dir', depth = 1 },
                { path = 'dir/dir2', file_type = 'dir', depth = 2 },
                { path = 'dir/file2', file_type = 'file', depth = 2 },
                { path = 'file', file_type = 'file', depth = 1 },
                { path = 'link', file_type = 'symlink', depth = 1 },
            })
        end)

        it('should support absolute paths if specified', function()
            local err, res = fn.read_dir({ path = root.path(), absolute = true })
            assert(not err, err)
            assert.are.same(res.entries, {
                { path = root.dir('dir').path(), file_type = 'dir', depth = 1 },
                { path = root.file('file').path(), file_type = 'file', depth = 1 },
                { path = root.symlink('link').path(), file_type = 'symlink', depth = 1 },
            })
        end)

        it('should support canonicalized paths if specified', function()
            local err, res = fn.read_dir({ path = root.path(), canonicalize = true })
            assert(not err, err)

            local f = function(a, b)
                if a.path == b.path then
                    if a.file_type == b.file_type then
                        return a.depth < b.depth
                    else
                        return a.file_type < b.file_type
                    end
                else
                    return a.path < b.path
                end
            end

            local expected = {
                { path = 'dir', file_type = 'dir', depth = 1 },
                { path = 'file', file_type = 'file', depth = 1 },
                -- Symlink gets resolved to file's path
                { path = 'file', file_type = 'symlink', depth = 1 },
            }
            local actual = res.entries

            table.sort(expected, f)
            table.sort(actual, f)

            -- NOTE: The order can vary here since the path is the same, which means that
            --       this assertion can fail sporadically if we use assert.are.same
            --       even though it is supposed to handle different ordering. So, we need
            --       to sort the tables first
            --
            --       https://github.com/Olivine-Labs/busted/issues/262
            assert.are.same(actual, expected)
        end)

        it('should include root path if specified', function()
            local err, res = fn.read_dir({ path = root.path(), include_root = true })
            assert(not err, err)
            assert.are.same(res.entries, {
                { path = root.canonicalized_path(), file_type = 'dir', depth = 0 },
                { path = 'dir', file_type = 'dir', depth = 1 },
                { path = 'file', file_type = 'file', depth = 1 },
                { path = 'link', file_type = 'symlink', depth = 1 },
            })
        end)

        it('should fail if the path does not exist', function()
            local dir = root.dir()
            local err, res = fn.read_dir({ path = dir.path() })
            assert.is.truthy(err)
            assert.is.falsy(res)
        end)

        -- distant and ssh modes behave differently here
        if driver:mode() == 'distant' then
            it('should return empty entries if path is to a file', function()
                local file = root.file()
                assert(file.touch(), 'Failed to create file: ' .. file.path())

                local err, res = fn.read_dir({ path = file.path() })
                assert.is.falsy(err)
                assert.are.same(res.entries, {})
            end)
        elseif driver:mode() == 'ssh' then
            it('should fail if path is to a file', function()
                local file = root.file()
                assert(file.touch(), 'Failed to create file: ' .. file.path())

                local err, res = fn.read_dir({ path = file.path() })
                assert.is.truthy(err)
                assert.is.falsy(res)
            end)
        end
    end)
end)
