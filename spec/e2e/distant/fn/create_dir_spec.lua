local fn = require('distant.fn')
local Driver = require('spec.e2e.driver')

describe('distant.fn', function()
    --- @type spec.e2e.Driver, spec.e2e.RemoteDir
    local driver, root

    before_each(function()
        driver = Driver:setup({ label = 'distant.fn.create_dir' })
        root = driver:new_dir_fixture()
    end)

    after_each(function()
        driver:teardown()
    end)

    describe('create_dir', function()
        it('should create a new directory', function()
            local dir = root:dir('dir')
            local err = fn.create_dir({ path = dir:path() })
            assert(not err, tostring(err))
            assert.is.truthy(dir:exists())
        end)

        it('should fail if creating multiple missing directory components if all not specified', function()
            local dir = root:dir('dir/dir2')
            local err = fn.create_dir({ path = dir:path() })
            assert.is.truthy(err)
            assert.is.falsy(dir:exists())
        end)

        it('should support creating multiple missing directory components if all specified', function()
            local dir = root:dir('dir/dir2')
            local err = fn.create_dir({ path = dir:path(), all = true })
            assert(not err, tostring(err))
            assert.is.truthy(dir:exists())
        end)
    end)
end)
