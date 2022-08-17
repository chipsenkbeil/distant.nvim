local fn = require('distant.fn')
local Driver = require('spec.e2e.driver')

describe('fn', function()
    local driver, root

    before_each(function()
        driver = Driver:setup({ label = 'fn.metadata' })
        root = driver:new_dir_fixture()
    end)

    after_each(function()
        driver:teardown()
    end)

    describe('metadata', function()
        it('should return metadata for files', function()
            local file = root.file()
            assert(file.touch(), 'Failed to create file: ' .. file.path())

            local err, res = fn.metadata({ path = file.path() })
            assert(not err, err)

            assert.are.equal(res.file_type, 'file')
            assert.is.falsy(res.canonicalized_path)
        end)

        it('should return metadata for directories', function()
            local dir = root.dir()
            assert(dir.make(), 'Failed to create directory: ' .. dir.path())

            local err, res = fn.metadata({ path = dir.path() })
            assert(not err, err)

            assert.are.equal(res.file_type, 'dir')
            assert.is.falsy(res.canonicalized_path)
        end)

        it('should support metadata for symlinks', function()
            local file = root.file()
            assert(file.touch(), 'Failed to create file: ' .. file.path())

            local symlink = root.symlink()
            assert(symlink.make(file.path()), 'Failed to create symlink: ' .. symlink.path())

            local err, res = fn.metadata({ path = symlink.path() })
            assert(not err, err)

            assert.are.equal(res.file_type, 'symlink')
        end)

        it('should support resolving symlinks to underlying type', function()
            local file = root.file()
            assert(file.touch(), 'Failed to create file: ' .. file.path())

            local symlink = root.symlink()
            assert(symlink.make(file.path()), 'Failed to create symlink: ' .. symlink.path())

            local err, res = fn.metadata({ path = symlink.path(), resolve_file_type = true })
            assert(not err, err)

            assert.are.equal(res.file_type, 'file')
        end)

        it('should support returning a canonicalized path', function()
            local file = root.file()
            assert(file.touch(), 'Failed to create file: ' .. file.path())

            local symlink = root.symlink()
            assert(symlink.make(file.path()), 'Failed to create symlink: ' .. symlink.path())

            local err, res = fn.metadata({ path = symlink.path(), canonicalize = true })
            assert(not err, err)

            assert.are.equal(res.file_type, 'symlink')
            assert.are.equal(res.canonicalized_path, file.path())
        end)

        it('should fail if the path does not exist', function()
            local file = root.file()
            local err, res = fn.metadata({ path = file.path() })
            assert.is.truthy(err)
            assert.is.falsy(res)
        end)
    end)
end)
