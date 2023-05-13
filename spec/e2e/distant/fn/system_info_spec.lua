local plugin = require('distant')
local Driver = require('spec.e2e.driver')

describe('distant.fn', function()
    --- @type spec.e2e.Driver
    local driver

    before_each(function()
        driver = Driver:setup({ label = 'distant.fn.system_info' })
    end)

    after_each(function()
        driver:teardown()
    end)

    describe('system_info', function()
        it('should report back information about remote machine', function()
            local err, res = plugin.fn.system_info({})
            assert(not err, tostring(err))

            -- TODO: Can we verify this any further? We'd need
            --       to make assumptions about the remote machine
            assert.is.truthy(res)
        end)

        it('should support being performed asynchronously', function()
            local info
            plugin.fn.system_info({}, function(err, res)
                assert(not err, tostring(err))
                info = res
            end)

            local time = 1000 * 5
            assert(
                vim.wait(time, function() return info ~= nil end),
                string.format('System information failed to be retrieved after %.2fs', time / 1000.0)
            )
        end)
    end)
end)
