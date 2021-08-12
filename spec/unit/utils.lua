local c = require('spec.unit.config')
local s = require('distant.internal.state')
local stub = require('luassert.stub')
local u = require('distant.internal.utils')

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

-- Stub the return value of state.client()
utils.stub_client = function(client)
   return stub(s, 'client', client)
end

-- Stub client's send method and invoke the provided function
-- with msg, cb as the arguments
utils.stub_send = function(f)
   return utils.stub_client({
        send = function(_, msg, cb)
            f(msg, cb)
        end
    })
end

-- Stub the client's send method and fake a response
utils.fake_response = function(res)
    return utils.stub_send(function(_, cb) cb(res) end)
end

return utils
