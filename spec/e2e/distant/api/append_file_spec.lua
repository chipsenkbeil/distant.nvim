local plugin = require('distant')
local Driver = require('spec.e2e.driver')

describe('distant.api.append_file', function()
    --- @type spec.e2e.Driver, spec.e2e.RemoteDir
    local driver, root

    before_each(function()
        driver = Driver:setup({ label = 'distant.api.append_file' })
        root = driver:new_dir_fixture()
    end)

    after_each(function()
        driver:teardown()
    end)

    --- @param s string
    --- @return integer[]
    local function tobytes(s)
        return { s:byte(1, #s) }
    end

    describe('synchronous', function()
        it('should create file with given bytes if it does not exist', function()
            local file = root:file()
            local err = plugin.api.append_file({ path = file:path(), data = tobytes('some text') })
            assert(not err, tostring(err))
            file.assert.same('some text')
        end)

        it('should append bytes to an existing file', function()
            local file = root:file()
            assert(file:write('abcdefg'), 'Failed to write to ' .. file:path())

            local err = plugin.api.append_file({ path = file:path(), data = tobytes('some text') })
            assert(not err, tostring(err))
            file.assert.same('abcdefgsome text')
        end)

        it('should fail if file path has multiple missing components', function()
            local file = root:file('file/file2')
            local err = plugin.api.append_file({ path = file:path(), data = tobytes('some text') })
            assert.is.truthy(err)
            assert.is.falsy(file:exists())
        end)
    end)

    describe('asynchronous', function()
        it('should create file with given bytes if it does not exist', function()
            local file = root:file()
            local capture = driver:new_capture()
            --- @diagnostic disable-next-line:param-type-mismatch
            plugin.api.append_file({ path = file:path(), data = tobytes('some text') }, capture)

            local err = capture.wait()
            assert(not err, tostring(err))
            file.assert.same('some text')
        end)

        it('should append bytes to an existing file', function()
            local file = root:file()
            assert(file:write('abcdefg'), 'Failed to write to ' .. file:path())

            local capture = driver:new_capture()
            --- @diagnostic disable-next-line:param-type-mismatch
            plugin.api.append_file({ path = file:path(), data = tobytes('some text') }, capture)

            local err = capture.wait()
            assert(not err, tostring(err))
            file.assert.same('abcdefgsome text')
        end)

        it('should fail if file path has multiple missing components', function()
            local file = root:file('file/file2')

            local capture = driver:new_capture()
            --- @diagnostic disable-next-line:param-type-mismatch
            plugin.api.append_file({ path = file:path(), data = tobytes('some text') }, capture)

            local err = capture.wait()
            assert.is.truthy(err)
            assert.is.falsy(file:exists())
        end)
    end)
end)
