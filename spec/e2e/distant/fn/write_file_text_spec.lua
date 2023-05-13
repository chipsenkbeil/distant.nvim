local plugin = require('distant')
local Driver = require('spec.e2e.driver')

describe('distant.api', function()
    --- @type spec.e2e.Driver, spec.e2e.RemoteDir
    local driver, root

    before_each(function()
        driver = Driver:setup({ label = 'distant.api.write_file_text' })
        root = driver:new_dir_fixture()
    end)

    after_each(function()
        driver:teardown()
    end)

    describe('write_file_text', function()
        it('should create file with given text if it does not exist', function()
            local file = root:file()
            local err = plugin.api.write_file_text({ path = file:path(), text = 'some text' })
            assert(not err, tostring(err))
            file.assert.same('some text')
        end)

        it('should overwrite existing file', function()
            local file = root:file()
            assert(file:write('abcdefg'), 'Failed to write to ' .. file:path())

            local err = plugin.api.write_file_text({ path = file:path(), text = 'some text' })
            assert(not err, tostring(err))
            file.assert.same('some text')
        end)

        it('should fail if file path has multiple missing components', function()
            local file = root:file('file/file2')
            local err = plugin.api.write_file_text({ path = file:path(), text = 'some text' })
            assert.is.truthy(err)
            assert.is.falsy(file:exists())
        end)
    end)
end)
