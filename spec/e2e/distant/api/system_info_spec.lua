local plugin = require('distant')
local Driver = require('spec.e2e.driver')

describe('distant.api.system_info', function()
    --- @type spec.e2e.Driver
    local driver

    before_each(function()
        driver = Driver:setup({ label = 'distant.api.system_info' })
    end)

    after_each(function()
        driver:teardown()
    end)

    describe('synchronous', function()
        it('should report back information about remote machine', function()
            local err, res = plugin.api.system_info({})
            assert(not err, tostring(err))

            -- TODO: Can we verify this any further? We'd need
            --       to make assumptions about the remote machine
            assert.is.truthy(res)
        end)
    end)

    describe('asynchronous', function()
        it('should report back information about remote machine', function()
            local capture = driver:new_capture()
            --- @diagnostic disable-next-line:param-type-mismatch
            plugin.api.system_info({}, capture)

            local err, res = capture.wait()
            assert(not err, tostring(err))

            -- TODO: Can we verify this any further? We'd need
            --       to make assumptions about the remote machine
            assert.is.truthy(res)
        end)
    end)
end)
