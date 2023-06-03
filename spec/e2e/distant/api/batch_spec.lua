local plugin = require('distant')
local Driver = require('spec.e2e.driver')

describe('distant.api.batch', function()
    --- @type spec.e2e.Driver, spec.e2e.RemoteDir
    local driver, root

    before_each(function()
        driver = Driver:setup({ label = 'distant.api.batch' })
        root = driver:new_dir_fixture()
    end)

    after_each(function()
        driver:teardown()
    end)

    describe('synchronous', function()
        it('should support sending a single payload', function()
            local err, results = plugin.api.batch({
                { type = 'system_info' },
            })

            -- Verify we did not get an error
            assert(not err, tostring(err))
            assert(results)

            -- { type = 'system_info', family = 'unix', ... }
            local res = assert(results[1])
            assert.are.equal(res.type, 'system_info')
            assert.is.truthy(res.family)
        end)

        it('should support sending multiple payloads', function()
            -- Create a file to distinguish some duplicate calls
            local file = root:file()
            file:touch()

            local err, results = plugin.api.batch({
                { type = 'exists',     path = file:path() },
                { type = 'exists',     path = '/path/to/file.txt' },
                { type = 'metadata',   path = '/path/to/file.txt' },
                { type = 'system_info' },
            })

            -- Verify we did not get an error
            assert(not err, tostring(err))
            assert(results)

            -- { type = 'exists', value = true }
            local res = assert(results[1])
            assert.are.equal(res.type, 'exists')
            assert.are.equal(res.value, true)

            -- { type = 'exists', value = false }
            local res = assert(results[2])
            assert.are.equal(res.type, 'exists')
            assert.are.equal(res.value, false)

            -- { type = 'error', kind = '...', description = '...' }
            local res = assert(results[3])
            assert.are.equal(res.type, 'error')
            assert.is.truthy(res.kind)
            assert.is.truthy(res.description)

            -- { payload = { family = 'unix', .. } }
            local res = assert(results[4])
            assert.are.equal(res.type, 'system_info')
            assert.is.truthy(res.family)
        end)
    end)

    describe('asynchronous', function()
        it('should support sending a single payload', function()
            local capture = driver:new_capture()

            plugin.api.batch(
                {
                    { type = 'system_info' },
                },
                --- @diagnostic disable-next-line:param-type-mismatch
                capture
            )

            --- @type distant.core.api.Error|nil, distant.core.batch.Response[]|nil
            local err, results = capture.wait()

            -- Verify we did not get an error
            assert(not err, tostring(err))
            assert(results)

            -- { type = 'system_info', family = 'unix', ... }
            local res = assert(results[1])
            assert.are.equal(res.type, 'system_info')
            assert.is.truthy(res.family)
        end)

        it('should support sending multiple payloads', function()
            -- Create a file to distinguish some duplicate calls
            local file = root:file()
            file:touch()

            local capture = driver:new_capture()
            plugin.api.batch(
                {
                    { type = 'exists',     path = file:path() },
                    { type = 'exists',     path = '/path/to/file.txt' },
                    { type = 'metadata',   path = '/path/to/file.txt' },
                    { type = 'system_info' },
                },
                --- @diagnostic disable-next-line:param-type-mismatch
                capture
            )

            --- @type distant.core.api.Error|nil, distant.core.batch.Response[]|nil
            local err, results = capture.wait()

            -- Verify we did not get an error
            assert(not err, tostring(err))
            assert(results)

            -- { type = 'exists', value = true }
            local res = assert(results[1])
            assert.are.equal(res.type, 'exists')
            assert.are.equal(res.value, true)

            -- { type = 'exists', value = false }
            local res = assert(results[2])
            assert.are.equal(res.type, 'exists')
            assert.are.equal(res.value, false)

            -- { type = 'error', kind = '...', description = '...' }
            local res = assert(results[3])
            assert.are.equal(res.type, 'error')
            assert.is.truthy(res.kind)
            assert.is.truthy(res.description)

            -- { payload = { family = 'unix', .. } }
            local res = assert(results[4])
            assert.are.equal(res.type, 'system_info')
            assert.is.truthy(res.family)
        end)
    end)
end)
