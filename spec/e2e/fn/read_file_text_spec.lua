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

    describe('read_file_text', function()
        it('should return text of remote file', function()
            local file = root.file()
            assert(file.write('some text'), 'Failed to write to ' .. file.path())

            local err, res = fn.read_file_text(file.path())
            assert(not err, err)
            assert.are.equal(res, 'some text')
        end)

        it('should fail if file does not exist', function()
            local file = root.file()
            local err, res = fn.read_file_text(file.path())
            assert.is.truthy(err)
            assert.is.falsy(res)
        end)
    end)
end)
