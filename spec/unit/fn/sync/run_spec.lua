local fn = require('distant.fn')
local s = require('distant.state')
local stub = require('luassert.stub')
local u = require('distant.utils')

describe('fn.run (sync)', function()
    before_each(function()
        -- Make our async fn do nothing as we're going to stub
        -- the channel return values separately
        stub(fn.async, 'run')
    end)

    it('should perform an async run and wait for the result', function()
        stub(u, 'oneshot_channel', 'fake tx', function()
            return false, false, true
        end)

        local err, result = fn.run('cmd', {'arg1', 'arg2'})
        assert.stub(fn.async.run).was.called_with('cmd', {'arg1', 'arg2'}, 'fake tx')
        assert.falsy(err)
        assert.truthy(result)
    end)

    it('should report a timeout error if the timeout is exceeded', function()
        stub(u, 'oneshot_channel', 'fake tx', function()
            return 'timeout error', false, true
        end)

        local err, _ = fn.run('cmd', {'arg1', 'arg2'})
        assert.are.equal('timeout error', err)
    end)

    it('should report the error of the async function if it returns one', function()
        stub(u, 'oneshot_channel', 'fake tx', function()
            return false, 'async error', true
        end)

        local err, _ = fn.run('cmd', {'arg1', 'arg2'})
        assert.are.equal('async error', err)
    end)

    it('should use timeout and interval options provided', function()
        stub(u, 'oneshot_channel', 'fake tx', function()
            return false, false, true
        end)

        fn.run('cmd', {'arg1', 'arg2'}, {
            timeout = 123,
            interval = 456,
        })
        assert.stub(u.oneshot_channel).was.called_with(123, 456)
    end)

    it('should default to setting timeout and interval', function()
        stub(u, 'oneshot_channel', 'fake tx', function()
            return false, false, true
        end)

        fn.run('cmd', {'arg1', 'arg2'})
        assert.stub(u.oneshot_channel).was.called_with(
            s.settings.max_timeout,
            s.settings.timeout_interval
        )
    end)
end)
