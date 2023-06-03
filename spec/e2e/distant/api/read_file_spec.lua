local plugin = require('distant')
local Driver = require('spec.e2e.driver')

describe('distant.api.read_file', function()
    --- @type spec.e2e.Driver, spec.e2e.RemoteDir
    local driver, root

    before_each(function()
        driver = Driver:setup({ label = 'distant.api.read_file' })
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
        it('should return text of remote file', function()
            local file = root:file()
            assert(file:write('some text'), 'Failed to write to ' .. file:path())

            local err, res = plugin.api.read_file({ path = file:path() })
            assert(not err, tostring(err))
            assert(res)
            assert.are.same(res, tobytes('some text'))
        end)

        it('should fail if file does not exist', function()
            local file = root:file()
            local err, res = plugin.api.read_file({ path = file:path() })
            assert.is.truthy(err)
            assert.is_nil(res)
        end)
    end)

    describe('asynchronous', function()
        it('should return text of remote file', function()
            local file = root:file()
            assert(file:write('some text'), 'Failed to write to ' .. file:path())

            local capture = driver:new_capture()
            --- @diagnostic disable-next-line:param-type-mismatch
            plugin.api.read_file({ path = file:path() }, capture)

            local err, res = capture.wait()
            assert(not err, tostring(err))
            assert(res)
            assert.are.same(res, tobytes('some text'))
        end)

        it('should fail if file does not exist', function()
            local file = root:file()

            local capture = driver:new_capture()
            --- @diagnostic disable-next-line:param-type-mismatch
            plugin.api.read_file({ path = file:path() }, capture)

            local err, res = capture.wait()
            assert.is.truthy(err)
            assert.is_nil(res)
        end)
    end)
end)
