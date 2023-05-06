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
        local err, a, b, c = rx()
        assert.is.falsy(err)
        assert.are.equal(1, a)
        assert.are.equal(2, b)
        assert.are.equal(3, c)
    end)

    it('should return tx, rx such that rx returns an error if the timeout is reached', function()
        local _, rx = utils.oneshot_channel(10, 1)
        local err, result = rx()
        assert.are.equal('Timeout of 10 exceeded!', err)
        assert.is.falsy(result)
    end)
end)
