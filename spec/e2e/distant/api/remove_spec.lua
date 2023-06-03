local plugin = require('distant')
local Driver = require('spec.e2e.driver')

describe('distant.api.remove', function()
    --- @type spec.e2e.Driver, spec.e2e.RemoteDir
    local driver, root

    before_each(function()
        driver = Driver:setup({ label = 'distant.api.remove' })
        root = driver:new_dir_fixture()
    end)

    after_each(function()
        driver:teardown()
    end)

    describe('synchronous', function()
        it('should remove a file if given a file path', function()
            local file = root:file()
            assert(file:touch(), 'Failed to create file: ' .. file:path())

            local err = plugin.api.remove({ path = file:path() })
            assert(not err, tostring(err))
            assert.is.falsy(file:exists())
        end)

        it('should remove an empty directory if given a directory path', function()
            local dir = root:dir()
            assert(dir:make(), 'Failed to create directory: ' .. dir:path())

            local err = plugin.api.remove({ path = dir:path() })
            assert(not err, tostring(err))
            assert.is.falsy(dir:exists())
        end)

        it('should remove a non-empty directory if given a directory path with force option', function()
            local dir = root:dir()
            assert(dir:make(), 'Failed to create directory: ' .. dir:path())
            assert(dir:file():touch(), 'Failed to create inner file')

            local err = plugin.api.remove({ path = dir:path(), force = true })
            assert(not err, tostring(err))
            assert.is.falsy(dir:exists())
        end)

        it('should fail if given a path to non-empty directory without force option', function()
            local dir = root:dir()
            assert(dir:make(), 'Failed to create directory: ' .. dir:path())
            local file = dir:file()
            assert(file:touch(), 'Failed to create file: ' .. file:path())

            local err = plugin.api.remove({ path = dir:path() })
            assert.is.truthy(err)
            assert.is.truthy(dir:exists())
            assert.is.truthy(file:exists())
        end)
    end)

    describe('asynchronous', function()
        it('should remove a file if given a file path', function()
            local file = root:file()
            assert(file:touch(), 'Failed to create file: ' .. file:path())

            local capture = driver:new_capture()
            --- @diagnostic disable-next-line:param-type-mismatch
            plugin.api.remove({ path = file:path() }, capture)

            local err = capture.wait()
            assert(not err, tostring(err))
            assert.is.falsy(file:exists())
        end)

        it('should remove an empty directory if given a directory path', function()
            local dir = root:dir()
            assert(dir:make(), 'Failed to create directory: ' .. dir:path())

            local capture = driver:new_capture()
            --- @diagnostic disable-next-line:param-type-mismatch
            plugin.api.remove({ path = dir:path() }, capture)

            local err = capture.wait()
            assert(not err, tostring(err))
            assert.is.falsy(dir:exists())
        end)

        it('should remove a non-empty directory if given a directory path with force option', function()
            local dir = root:dir()
            assert(dir:make(), 'Failed to create directory: ' .. dir:path())
            assert(dir:file():touch(), 'Failed to create inner file')

            local capture = driver:new_capture()
            --- @diagnostic disable-next-line:param-type-mismatch
            plugin.api.remove({ path = dir:path(), force = true }, capture)

            local err = capture.wait()
            assert(not err, tostring(err))
            assert.is.falsy(dir:exists())
        end)

        it('should fail if given a path to non-empty directory without force option', function()
            local dir = root:dir()
            assert(dir:make(), 'Failed to create directory: ' .. dir:path())
            local file = dir:file()
            assert(file:touch(), 'Failed to create file: ' .. file:path())

            local capture = driver:new_capture()
            --- @diagnostic disable-next-line:param-type-mismatch
            plugin.api.remove({ path = dir:path() }, capture)

            local err = capture.wait()
            assert.is.truthy(err)
            assert.is.truthy(dir:exists())
            assert.is.truthy(file:exists())
        end)
    end)
end)
