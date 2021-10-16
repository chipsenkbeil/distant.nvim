local c = require('spec.unit.config')
local lib = require('distant.lib')
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

-- Replaces `distant.lib.load(...)` such that it always returns the fake library
utils.set_fake_lib = function(fake_lib)
    lib.load = function(cb)
        cb(true, fake_lib)
    end
end

return utils
