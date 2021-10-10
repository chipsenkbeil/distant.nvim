local fn = require('distant.fn')
local Driver = require('spec.e2e.driver')

describe('fn', function()
    local driver, root

    before_each(function()
        driver = Driver:setup()
        root = driver:new_dir_fixture()
    end)

    after_each(function()
        driver:teardown()
    end)

    describe('remove', function()
        it('should remove a file if given a file path', function()
            local file = root.file()
            assert(file.touch(), 'Failed to create file: ' .. file.path())

            local err, res = fn.remove({path = file.path()})
            assert(not err, err)
            assert.is.truthy(res)
            assert.is.falsy(file.exists())
        end)

        it('should remove an empty directory if given a directory path', function()
            local dir = root.dir()
            assert(dir.make(), 'Failed to create directory: ' .. dir.path())

            local err, res = fn.remove({path = dir.path()})
            assert(not err, err)
            assert.is.truthy(res)
            assert.is.falsy(dir.exists())
        end)

        it('should remove a non-empty directory if given a directory path with force option', function()
            local dir = root.dir()
            assert(dir.make(), 'Failed to create directory: ' .. dir.path())
            assert(dir.file().touch(), 'Failed to create inner file')

            local err, res = fn.remove({path = dir.path(), force = true})
            assert(not err, err)
            assert.is.truthy(res)
            assert.is.falsy(dir.exists())
        end)

        it('should fail if given a path to non-empty directory without force option', function()
            local dir = root.dir()
            assert(dir.make(), 'Failed to create directory: ' .. dir.path())
            local file = dir.file()
            assert(file.touch(), 'Failed to create file: ' .. file.path())

            local err, res = fn.remove({path = dir.path()})
            assert.is.truthy(err)
            assert.is.falsy(res)
            assert.is.truthy(dir.exists())
            assert.is.truthy(file.exists())
        end)
    end)
end)
