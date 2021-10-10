local fn = require('distant.fn')
local match = require('luassert.match')
local spy = require('luassert.spy')
local u = require('spec.unit.utils')

describe('fn.rename (async)', function()
    it('should send a rename request via the global client', function()
        local send = spy.new(function() end)
        u.stub_send(send)

        fn.async.rename('src', 'dst', function() end)

        local _ = match._
        assert.spy(send).was.called_with(match.is_same({
            type = 'rename',
            data = {
                src = 'src',
                dst = 'dst',
            }
        }), _)
    end)

    it('should invoke the callback with appropriate result on success', function()
        u.fake_response({ type = 'ok', data = {} })

        local done, wait = u.make_channel()
        fn.async.rename('src', 'dst', function(err, data)
            assert.is.falsy(err)
            assert.are.same(true, data)
            done()
        end)
        wait()
    end)

    it('should invoke the callback with an error if nil received', function()
        u.fake_response(nil)

        local done, wait = u.make_channel()
        fn.async.rename('src', 'dst', function(err, data)
            assert.is.same('Nil response received', err)
            assert.is.falsy(data)
            done()
        end)
        wait()
    end)

    it('should invoke the callback with an error if "error" type received', function()
        u.fake_response({ type = 'error', data = { description = 'some error msg' } })

        local done, wait = u.make_channel()
        fn.async.rename('src', 'dst', function(err, data)
            assert.is.same('some error msg', err)
            assert.is.falsy(data)
            done()
        end)
        wait()
    end)

    it('should invoke the callback with an error if "error" type received without payload', function()
        u.fake_response({ type = 'error' })

        local done, wait = u.make_channel()
        fn.async.rename('src', 'dst', function(err, data)
            assert.is.same('Error response received without data payload', err)
            assert.is.falsy(data)
            done()
        end)
        wait()
    end)

    it('should invoke the callback with an error if "error" type received without description', function()
        u.fake_response({ type = 'error', data = {} })

        local done, wait = u.make_channel()
        fn.async.rename('src', 'dst', function(err, data)
            assert.is.same('Error response received without description', err)
            assert.is.falsy(data)
            done()
        end)
        wait()
    end)

    it('should invoke the callback with an error if not correct type received', function()
        u.fake_response({ type = 'other', data = {} })

        local done, wait = u.make_channel()
        fn.async.rename('src', 'dst', function(err, data)
            assert.is.same('Received invalid response of type other', err)
            assert.is.falsy(data)
            done()
        end)
        wait()
    end)
end)
