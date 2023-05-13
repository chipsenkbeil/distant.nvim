local plugin = require('distant')
local Driver = require('spec.e2e.driver')

describe('distant.fn', function()
    --- @type spec.e2e.Driver, spec.e2e.RemoteDir
    local driver, root

    before_each(function()
        driver = Driver:setup({ label = 'distant.fn.read_file_text' })
        root = driver:new_dir_fixture()
    end)

    after_each(function()
        driver:teardown()
    end)

    describe('read_file_text', function()
        it('should return text of remote file', function()
            local file = root:file()
            assert(file:write('some text'), 'Failed to write to ' .. file:path())

            local err, res = plugin.fn.read_file_text({ path = file:path() })
            assert(not err, tostring(err))
            assert(res)
            assert.are.equal(res, 'some text')
        end)

        it('should fail if file does not exist', function()
            local file = root:file()
            local err, res = plugin.fn.read_file_text({ path = file:path() })
            assert.is.truthy(err)
            assert.is_nil(res)
        end)
    end)
end)
