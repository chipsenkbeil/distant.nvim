local fn = require('distant.fn')
local Driver = require('spec.e2e.driver')

describe('fn', function()
    local driver, dir, file

    before_each(function()
        driver = Driver:setup()

        -- Create a test dir and file on the remote machine
        dir = driver:new_dir_fixture()
        file = dir.file()

        -- Populate test file with some content
        file.write('some file content')
    end)

    after_each(function()
        driver:teardown()
    end)

    describe('copy', function()
        it('should copy a src file to a destination', function()
            local dst = dir.file()

            local err, res = fn.copy(file.path(), dst.path())
            assert(not err, err)
            assert.is.truthy(res)

            -- Ensure that the new file matches the old file
            file.assert.same({'some file content'})
            dst.assert.same({'some file content'})
        end)
    end)
end)
