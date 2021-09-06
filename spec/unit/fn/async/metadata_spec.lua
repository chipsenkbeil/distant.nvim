local fn = require('distant.fn')
local match = require('luassert.match')
local spy = require('luassert.spy')
local u = require('spec.unit.utils')

describe('fn.async.metadata', function()
    it('should send a metadata request via the global client', function()
        local send = spy.new(function() end)
        u.stub_send(send)

        local path = 'some/path'
        fn.async.metadata(path, {}, function() end)

        local _ = match._
        assert.spy(send).was.called_with(match.is_same({
            type = 'metadata',
            data = {
                path = path,
                canonicalize = false,
                resolve_file_type = false,
            }
        }), _)
    end)

    it('should use option values for part of message when provided', function()
        local send = spy.new(function() end)
        u.stub_send(send)

        local path = 'some/path'
        fn.async.metadata(path, {
            canonicalize = true,
            resolve_file_type = true,
        }, function() end)

        local _ = match._
        assert.spy(send).was.called_with(match.is_same({
            type = 'metadata',
            data = {
                path = path,
                canonicalize = true,
                resolve_file_type = true,
            }
        }), _)
    end)

    it('should invoke the callback with appropriate result on success', function()
        u.fake_response({
            type = 'metadata',
            data = { is_file = true },
        })

        local done, wait = u.make_channel()
        fn.async.metadata('some/path', {}, function(err, data)
            assert.is.falsy(err)
            assert.are.same({ is_file = true }, data)
            done()
        end)
        wait()
    end)

    it('should clean up canonicalized_path if comes in as vim.NIL', function()
        u.fake_response({
            type = 'metadata',
            data = { canonicalized_path = vim.NIL },
        })

        local done, wait = u.make_channel()
        fn.async.metadata('some/path', {}, function(err, data)
            assert.is.falsy(err)
            assert.are.same({}, data)
            done()
        end)
        wait()
    end)

    it('should invoke the callback with an error if nil received', function()
        u.fake_response(nil)

        local done, wait = u.make_channel()
        fn.async.metadata('some/path', {}, function(err, data)
            assert.is.same('Nil response received', err)
            assert.is.falsy(data)
            done()
        end)
        wait()
    end)

    it('should invoke the callback with an error if "error" type received', function()
        u.fake_response({ type = 'error', data = { description = 'some error msg' } })

        local done, wait = u.make_channel()
        fn.async.metadata('some/path', {}, function(err, data)
            assert.is.same('some error msg', err)
            assert.is.falsy(data)
            done()
        end)
        wait()
    end)

    it('should invoke the callback with an error if "error" type received without payload', function()
        u.fake_response({ type = 'error' })

        local done, wait = u.make_channel()
        fn.async.metadata('some/path', {}, function(err, data)
            assert.is.same('Error response received without data payload', err)
            assert.is.falsy(data)
            done()
        end)
        wait()
    end)

    it('should invoke the callback with an error if "error" type received without description', function()
        u.fake_response({ type = 'error', data = {} })

        local done, wait = u.make_channel()
        fn.async.metadata('some/path', {}, function(err, data)
            assert.is.same('Error response received without description', err)
            assert.is.falsy(data)
            done()
        end)
        wait()
    end)

    it('should invoke the callback with an error if not correct type received', function()
        u.fake_response({ type = 'other', data = {} })

        local done, wait = u.make_channel()
        fn.async.metadata('some/path', {}, function(err, data)
            assert.is.same('Received invalid response of type other', err)
            assert.is.falsy(data)
            done()
        end)
        wait()
    end)
end)
