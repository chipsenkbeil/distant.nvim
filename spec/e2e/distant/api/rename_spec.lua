local plugin = require('distant')
local Driver = require('spec.e2e.driver')

describe('distant.api.rename', function()
    --- @type spec.e2e.Driver, spec.e2e.RemoteDir
    local driver, root

    before_each(function()
        driver = Driver:setup({ label = 'distant.api.rename' })
        root = driver:new_dir_fixture()
    end)

    after_each(function()
        driver:teardown()
    end)

    describe('synchronous', function()
        it('should rename a file to the specified new path', function()
            local src = root:file()
            assert(src:write('some text'), 'Failed to create file: ' .. src:path())

            local dst = root:file()

            local err = plugin.api.rename({ src = src:path(), dst = dst:path() })
            assert(not err, tostring(err))

            assert.is.falsy(src:exists())
            dst.assert.same('some text')
        end)

        it('should rename a directory to the specified new path', function()
            local src = root:dir()
            assert(src:make(), 'Failed to create directory: ' .. src:path())

            local src_file = src:file('file')
            assert(src_file:write('some text'), 'Failed to create directory: ' .. src_file:path())

            local dst = root:dir()

            local err = plugin.api.rename({ src = src:path(), dst = dst:path() })
            assert(not err, tostring(err))

            assert.is.falsy(src:exists())
            assert.is.falsy(src_file:exists())

            assert.is.truthy(dst:exists())
            dst:file('file').assert.same('some text')
        end)

        it('should fail if destination has multiple missing components', function()
            local src = root:file()
            assert(src:write('some text'), 'Failed to create file: ' .. src:path())

            local dst = root:dir('dir/dir2')

            local err = plugin.api.rename({ src = src:path(), dst = dst:path() })
            assert.is.truthy(err)

            assert.is.truthy(src:exists())
            assert.is.falsy(dst:exists())
        end)

        it('should fail if source path does not exist', function()
            local src = root:file()
            local dst = root:file()

            local err = plugin.api.rename({ src = src:path(), dst = dst:path() })
            assert.is.truthy(err)

            assert.is.falsy(src:exists())
            assert.is.falsy(dst:exists())
        end)
    end)

    describe('asynchronous', function()
        it('should rename a file to the specified new path', function()
            local src = root:file()
            assert(src:write('some text'), 'Failed to create file: ' .. src:path())

            local dst = root:file()

            local capture = driver:new_capture()
            --- @diagnostic disable-next-line:param-type-mismatch
            plugin.api.rename({ src = src:path(), dst = dst:path() }, capture)

            local err = capture.wait()
            assert(not err, tostring(err))

            assert.is.falsy(src:exists())
            dst.assert.same('some text')
        end)

        it('should rename a directory to the specified new path', function()
            local src = root:dir()
            assert(src:make(), 'Failed to create directory: ' .. src:path())

            local src_file = src:file('file')
            assert(src_file:write('some text'), 'Failed to create directory: ' .. src_file:path())

            local dst = root:dir()

            local capture = driver:new_capture()
            --- @diagnostic disable-next-line:param-type-mismatch
            plugin.api.rename({ src = src:path(), dst = dst:path() }, capture)

            local err = capture.wait()
            assert(not err, tostring(err))

            assert.is.falsy(src:exists())
            assert.is.falsy(src_file:exists())

            assert.is.truthy(dst:exists())
            dst:file('file').assert.same('some text')
        end)

        it('should fail if destination has multiple missing components', function()
            local src = root:file()
            assert(src:write('some text'), 'Failed to create file: ' .. src:path())

            local dst = root:dir('dir/dir2')

            local capture = driver:new_capture()
            --- @diagnostic disable-next-line:param-type-mismatch
            plugin.api.rename({ src = src:path(), dst = dst:path() }, capture)

            local err = capture.wait()
            assert.is.truthy(err)

            assert.is.truthy(src:exists())
            assert.is.falsy(dst:exists())
        end)

        it('should fail if source path does not exist', function()
            local src = root:file()
            local dst = root:file()

            local capture = driver:new_capture()
            --- @diagnostic disable-next-line:param-type-mismatch
            plugin.api.rename({ src = src:path(), dst = dst:path() }, capture)

            local err = capture.wait()
            assert.is.truthy(err)

            assert.is.falsy(src:exists())
            assert.is.falsy(dst:exists())
        end)
    end)
end)
