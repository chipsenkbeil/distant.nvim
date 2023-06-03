local plugin = require('distant')
local Driver = require('spec.e2e.driver')

describe('distant.api.copy', function()
    --- @type spec.e2e.Driver, spec.e2e.RemoteDir
    local driver, root

    before_each(function()
        driver = Driver:setup({ label = 'distant.api.copy' })
        root = driver:new_dir_fixture()
    end)

    after_each(function()
        driver:teardown()
    end)

    describe('synchronous', function()
        it('should copy a src file to a destination', function()
            local src = root:file()
            assert(src:write('some text'), 'Failed to make file: ' .. src:path())

            local dst = root:file()

            local err = plugin.api.copy({ src = src:path(), dst = dst:path() })
            assert(not err, tostring(err))

            src.assert.same({ 'some text' })
            dst.assert.same({ 'some text' })
        end)

        it('should copy a src directory to a destination', function()
            local src = root:dir()
            assert(src:make(), 'Failed to make directory: ' .. src:path())

            local src_file = src:file('file')
            assert(src_file:write('some text'), 'Failed to make file: ' .. src_file:path())

            local dst = root:dir()

            local err = plugin.api.copy({ src = src:path(), dst = dst:path() })
            assert(not err, tostring(err))

            assert.is.truthy(src:exists())
            src_file.assert.same({ 'some text' })

            assert.is.truthy(dst:exists())
            dst:file('file').assert.same({ 'some text' })
        end)

        it('should fail if src path does not exist', function()
            local src = root:file()
            local dst = root:file()

            local err = plugin.api.copy({ src = src:path(), dst = dst:path() })
            assert.is.truthy(err)

            assert.is.falsy(src:exists())
            assert.is.falsy(dst:exists())
        end)

        it('should fail if dst path has multiple missing components', function()
            local src = root:file()
            assert(src:touch(), 'Failed to make file: ' .. src:path())

            local dst = root:file('dir/file')

            local err = plugin.api.copy({ src = src:path(), dst = dst:path() })
            assert.is.truthy(err)

            assert.is.truthy(src:exists())
            assert.is.falsy(dst:exists())
        end)
    end)

    describe('asynchronous', function()
        it('should copy a src file to a destination', function()
            local src = root:file()
            assert(src:write('some text'), 'Failed to make file: ' .. src:path())

            local dst = root:file()

            local capture = driver:new_capture()
            plugin.api.copy(
                { src = src:path(), dst = dst:path() },
                --- @diagnostic disable-next-line:param-type-mismatch
                capture
            )

            local err = capture.wait()
            assert(not err, tostring(err))

            src.assert.same({ 'some text' })
            dst.assert.same({ 'some text' })
        end)

        it('should copy a src directory to a destination', function()
            local src = root:dir()
            assert(src:make(), 'Failed to make directory: ' .. src:path())

            local src_file = src:file('file')
            assert(src_file:write('some text'), 'Failed to make file: ' .. src_file:path())

            local dst = root:dir()

            local capture = driver:new_capture()
            plugin.api.copy(
                { src = src:path(), dst = dst:path() },
                --- @diagnostic disable-next-line:param-type-mismatch
                capture
            )

            local err = capture.wait()
            assert(not err, tostring(err))

            assert.is.truthy(src:exists())
            src_file.assert.same({ 'some text' })

            assert.is.truthy(dst:exists())
            dst:file('file').assert.same({ 'some text' })
        end)

        it('should fail if src path does not exist', function()
            local src = root:file()
            local dst = root:file()

            local capture = driver:new_capture()
            plugin.api.copy(
                { src = src:path(), dst = dst:path() },
                --- @diagnostic disable-next-line:param-type-mismatch
                capture
            )

            local err = capture.wait()
            assert.is.truthy(err)

            assert.is.falsy(src:exists())
            assert.is.falsy(dst:exists())
        end)

        it('should fail if dst path has multiple missing components', function()
            local src = root:file()
            assert(src:touch(), 'Failed to make file: ' .. src:path())

            local dst = root:file('dir/file')

            local capture = driver:new_capture()
            plugin.api.copy(
                { src = src:path(), dst = dst:path() },
                --- @diagnostic disable-next-line:param-type-mismatch
                capture
            )

            local err = capture.wait()
            assert.is.truthy(err)

            assert.is.truthy(src:exists())
            assert.is.falsy(dst:exists())
        end)
    end)
end)
