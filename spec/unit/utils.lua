local c = require('spec.unit.config')
local u = require('distant.utils')

local utils = {}

-- Returns done(), wait()
utils.make_channel = function()
    local tx, rx = u.oneshot_channel(c.timeout, c.timeout_interval)
    local function done()
        tx(true)
    end

    local function wait()
        local err, success = rx()
        assert.is.falsy(err)
        assert.is.truthy(success)
    end

    return done, wait
end

return utils
