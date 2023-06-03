local plugin = require('distant')
local Driver = require('spec.e2e.driver')

describe('distant.api.create_dir', function()
    --- @type spec.e2e.Driver, spec.e2e.RemoteDir
    local driver, root

    before_each(function()
        driver = Driver:setup({ label = 'distant.api.create_dir' })
        root = driver:new_dir_fixture()
    end)

    after_each(function()
        driver:teardown()
    end)

    describe('synchronous', function()
        it('should create a new directory', function()
            local dir = root:dir('dir')
            local err = plugin.api.create_dir({ path = dir:path() })
            assert(not err, tostring(err))
            assert.is.truthy(dir:exists())
        end)

        it('should fail if creating multiple missing directory components if all not specified', function()
            local dir = root:dir('dir/dir2')
            local err = plugin.api.create_dir({ path = dir:path() })
            assert.is.truthy(err)
            assert.is.falsy(dir:exists())
        end)

        it('should support creating multiple missing directory components if all specified', function()
            local dir = root:dir('dir/dir2')
            local err = plugin.api.create_dir({ path = dir:path(), all = true })
            assert(not err, tostring(err))
            assert.is.truthy(dir:exists())
        end)
    end)

    describe('asynchronous', function()
        it('should create a new directory', function()
            local dir = root:dir('dir')

            local capture = driver:new_capture()
            --- @diagnostic disable-next-line:param-type-mismatch
            plugin.api.create_dir({ path = dir:path() }, capture)

            local err = capture.wait()
            assert(not err, tostring(err))
            assert.is.truthy(dir:exists())
        end)

        it('should fail if creating multiple missing directory components if all not specified', function()
            local dir = root:dir('dir/dir2')

            local capture = driver:new_capture()
            --- @diagnostic disable-next-line:param-type-mismatch
            plugin.api.create_dir({ path = dir:path() }, capture)

            local err = capture.wait()
            assert.is.truthy(err)
            assert.is.falsy(dir:exists())
        end)

        it('should support creating multiple missing directory components if all specified', function()
            local dir = root:dir('dir/dir2')

            local capture = driver:new_capture()
            --- @diagnostic disable-next-line:param-type-mismatch
            plugin.api.create_dir({ path = dir:path(), all = true }, capture)

            local err = capture.wait()
            assert(not err, tostring(err))
            assert.is.truthy(dir:exists())
        end)
    end)
end)
