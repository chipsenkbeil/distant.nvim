local fn = require('distant.fn')
local Driver = require('spec.e2e.driver')

describe('fn', function()
    local driver, root

    before_each(function()
        driver = Driver:setup()

        -- Create a test dir and file on the remote machine
        root = driver:new_dir_fixture()
    end)

    after_each(function()
        driver:teardown()
    end)

    describe('mkdir', function()
        it('should create a new directory', function()
            local dir = root.dir('dir')
            local err, res = fn.mkdir(dir.path())
            assert(not err, err)
            assert.is.truthy(res)
            assert.is.truthy(dir.exists())
        end)

        it('should fail if creating multiple missing directory components if all not specified', function()
            local dir = root.dir('dir/dir2')
            local err, res = fn.mkdir(dir.path())
            assert.is.truthy(err)
            assert.is.falsy(res)
            assert.is.falsy(dir.exists())
        end)

        it('should support creating multiple missing directory components if all specified', function()
            local dir = root.dir('dir/dir2')
            local err, res = fn.mkdir(dir.path(), {all = true})
            assert(not err, err)
            assert.is.truthy(res)
            assert.is.truthy(dir.exists())
        end)
    end)
end)
