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

    describe('append_file_text', function()
        it('should create file with given text if it does not exist', function()
            local file = root.file()
            local err, res = fn.append_file_text({path = file.path(), text = 'some text'})
            assert(not err, err)
            assert.is.truthy(res)
            file.assert.same('some text')
        end)

        it('should append text to an existing file', function()
            local file = root.file()
            assert(file.write('abcdefg'), 'Failed to write to ' .. file.path())

            local err, res = fn.append_file_text({path = file.path(), text = 'some text'})
            assert(not err, err)
            assert.is.truthy(res)
            file.assert.same('abcdefgsome text')
        end)

        it('should fail if file path has multiple missing components', function()
            local file = root.file('file/file2')
            local err, res = fn.append_file_text({path = file.path(), text = 'some text'})
            assert.is.truthy(err)
            assert.is.falsy(res)
            assert.is.falsy(file.exists())
        end)
    end)
end)
