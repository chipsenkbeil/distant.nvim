local config = require('spec.unit.config')
local utils = require('distant-core.utils')

local M = {}

-- Returns done(), wait()
M.make_channel = function()
    local tx, rx = utils.oneshot_channel(config.timeout, config.timeout_interval)
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

return M
