local fn = require('distant.fn')
local Driver = require('spec.e2e.driver')

local driver = Driver:setup({ label = 'fn.system_info' })

describe('fn', function()

    before_each(function()
    end)

    after_each(function()
    end)

    describe('system_info', function()
        it('should report back information about remote machine', function()
            local err, res = fn.system_info()
            assert(not err, err)

            -- TODO: Can we verify this any further? We'd need
            --       to make assumptions about the remote machine
            assert.is.truthy(res)
        end)
    end)
end)

driver:teardown()
