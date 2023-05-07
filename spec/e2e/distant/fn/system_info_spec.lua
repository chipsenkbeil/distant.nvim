local fn = require('distant.fn')
local Driver = require('spec.e2e.driver')

describe('distant.fn', function()
    --- @type spec.e2e.Driver
    local driver

    before_each(function()
        driver = Driver:setup({ label = 'fn.system_info' })
    end)

    after_each(function()
        driver:teardown()
    end)

    describe('system_info', function()
        it('should report back information about remote machine', function()
            local err, res = fn.system_info({})
            assert(not err, err)

            -- TODO: Can we verify this any further? We'd need
            --       to make assumptions about the remote machine
            assert.is.truthy(res)
        end)
    end)
end)
