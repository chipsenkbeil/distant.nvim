local plugin = require('distant')
local Driver = require('spec.e2e.driver')

describe('distant.api.version', function()
    --- @type spec.e2e.Driver
    local driver

    before_each(function()
        driver = Driver:setup({ label = 'distant.api.version' })
    end)

    after_each(function()
        driver:teardown()
    end)

    it('should report back capabilities of the server', function()
        local err, res = plugin.api.version({})
        assert(not err, tostring(err))
        assert(res)

        -- TODO: Can we verify this any further? We'd need
        --       to make assumptions about the remote server
        assert.is.truthy(res.server_version)
        assert.is.truthy(res.protocol_version)
        assert.is.truthy(res.capabilities)
    end)
end)
