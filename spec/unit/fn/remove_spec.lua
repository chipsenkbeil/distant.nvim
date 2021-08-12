local fn = require('distant.fn')
local s = require('distant.internal.state')
local stub = require('luassert.stub')
local u = require('distant.internal.utils')

describe('fn.remove', function()
    before_each(function()
        -- Make our async fn do nothing as we're going to stub
        -- the channel return values separately
        stub(fn.async, 'remove')
    end)

    it('should perform an async remove and wait for the result', function()
        stub(u, 'oneshot_channel', 'fake tx', function()
            return false, false, true
        end)

        local path = 'some/path'
        local err, result = fn.remove(path)
        assert.stub(fn.async.remove).was.called_with(path, {}, 'fake tx')
        assert.falsy(err)
        assert.truthy(result)
    end)

    it('should pass options to the async function', function()
        stub(u, 'oneshot_channel', 'fake tx', function()
            return false, false, true
        end)

        local path = 'some/path'
        local opts = {force = true}
        local _ = fn.remove(path, opts)
        assert.stub(fn.async.remove).was.called_with(path, opts, 'fake tx')
    end)

    it('should report a timeout error if the timeout is exceeded', function()
        stub(u, 'oneshot_channel', 'fake tx', function()
            return 'timeout error', false, true
        end)

        local err, _ = fn.remove('some/path')
        assert.are.equal('timeout error', err)
    end)

    it('should report the error of the async function if it returns one', function()
        stub(u, 'oneshot_channel', 'fake tx', function()
            return false, 'async error', true
        end)

        local err, _ = fn.remove('some/path')
        assert.are.equal('async error', err)
    end)

    it('should use timeout and interval options provided', function()
        stub(u, 'oneshot_channel', 'fake tx', function()
            return false, false, true
        end)

        fn.remove('some/path', {
            timeout = 123,
            interval = 456,
        })
        assert.stub(u.oneshot_channel).was.called_with(123, 456)
    end)

    it('should default to setting timeout and interval', function()
        stub(u, 'oneshot_channel', 'fake tx', function()
            return false, false, true
        end)

        fn.remove('some/path')
        assert.stub(u.oneshot_channel).was.called_with(
            s.settings.max_timeout,
            s.settings.timeout_interval
        )
    end)
end)
