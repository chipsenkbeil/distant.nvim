local utils = require('distant-core.utils')

describe('distant-core.utils.oneshot_channel', function()
    it('should fail if timeout or interval are not numbers', function()
        assert.has.errors(function()
            --- @diagnostic disable-next-line:param-type-mismatch
            utils.oneshot_channel(0, 'not a number')
        end)

        assert.has.errors(function()
            --- @diagnostic disable-next-line:param-type-mismatch
            utils.oneshot_channel('not a number', 0)
        end)
    end)

    it('should return tx, rx such that rx returns whatever tx passes it', function()
        local tx, rx = utils.oneshot_channel(100, 10)
        tx(1, 2, 3)
        local a, b, c = rx()
        assert.are.equal(1, a)
        assert.are.equal(2, b)
        assert.are.equal(3, c)
    end)

    it('should return tx, rx such that rx fails if the timeout is reached', function()
        local _, rx = utils.oneshot_channel(10, 1)
        assert.has.errors(function()
            rx()
        end)
    end)
end)
