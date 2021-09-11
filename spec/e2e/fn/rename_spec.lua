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

    describe('rename', function()
        it('should rename a file to the specified new path', function()
            local src = root.file()
            assert(src.write('some text'), 'Failed to create file: ' .. src.path())

            local dst = root.file()

            local err, res = fn.rename(src.path(), dst.path())
            assert(not err, err)
            assert.is.truthy(res)

            assert.is.falsy(src.exists())
            dst.assert.same('some text')
        end)

        it('should rename a directory to the specified new path', function()
            local src = root.dir()
            assert(src.make(), 'Failed to create directory: ' .. src.path())

            local src_file = src.file('file')
            assert(src_file.write('some text'), 'Failed to create directory: ' .. src_file.path())

            local dst = root.dir()

            local err, res = fn.rename(src.path(), dst.path())
            assert(not err, err)
            assert.is.truthy(res)

            assert.is.falsy(src.exists())
            assert.is.falsy(src_file.exists())

            assert.is.truthy(dst.exists())
            dst.file('file').assert.same('some text')
        end)

        it('should fail if destination has multiple missing components', function()
            local src = root.file()
            assert(src.write('some text'), 'Failed to create file: ' .. src.path())

            local dst = root.dir('dir/dir2')

            local err, res = fn.rename(src.path(), dst.path())
            assert.is.truthy(err)
            assert.is.falsy(res)

            assert.is.truthy(src.exists())
            assert.is.falsy(dst.exists())
        end)

        it('should fail if source path does not exist', function()
            local src = root.file()
            local dst = root.file()

            local err, res = fn.rename(src.path(), dst.path())
            assert.is.truthy(err)
            assert.is.falsy(res)

            assert.is.falsy(src.exists())
            assert.is.falsy(dst.exists())
        end)
    end)
end)
