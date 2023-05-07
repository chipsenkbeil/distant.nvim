local fn = require('distant.fn')
local Driver = require('spec.e2e.driver')

describe('distant.fn', function()
    --- @type spec.e2e.Driver, spec.e2e.RemoteDir, spec.e2e.RemoteFile
    local driver, root, file

    before_each(function()
        driver = Driver:setup({ label = 'distant.fn.exists' })
        root = driver:new_dir_fixture()

        file = root:file()
        assert(file:touch(), 'Failed to create file: ' .. file:path())
    end)

    after_each(function()
        driver:teardown()
    end)

    describe('exists', function()
        it('should return true when path exists', function()
            local err, res = fn.exists({ path = file:path() })
            assert(not err, tostring(err))
            assert(res == true, 'Invalid return from exists: ' .. vim.inspect(res))
        end)

        it('should return false when path does not exist', function()
            local err, res = fn.exists({ path = file:path() .. '123' })
            assert(not err, tostring(err))
            assert(res == false, 'Invalid return from exists: ' .. vim.inspect(res))
        end)
    end)
end)
