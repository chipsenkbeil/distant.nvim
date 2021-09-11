local fn = require('distant.fn')
local match = require('luassert.match')
local spy = require('luassert.spy')
local u = require('spec.unit.utils')

local function stub_client(send, rb, urb)
    u.stub_client({
        send = function(_, msg, cb)
            return send(msg, cb)
        end,
        register_broadcast = function(_, cb)
            return rb(cb)
        end,
        unregister_broadcast = function(_, id)
            return urb(id)
        end,
    })
end

-- Stubs out client to just send back a fake response and ignores
-- calls to broadcast register/unregister by default (unless provided)
local function fake_response(res, rb, urb)
    rb = rb or function() end
    urb = urb or function() end
    stub_client(function(_, cb) cb(res) end, rb, urb)
end

describe('fn.async.run', function()
    it('should send a run request via the global client', function()
        local send = spy.new(function() end)
        local rb = spy.new(function() return 123 end)
        local urb = spy.new(function() end)
        stub_client(send, rb, urb)

        local cmd = 'cmd'
        local args = {'arg1', 'arg2'}
        fn.async.run(cmd, args, function() end)

        local _ = match._
        assert.spy(send).was.called_with(match.is_same({
            type = 'proc_run',
            data = {
                cmd = cmd,
                args = args,
            }
        }), _)
        assert.spy(rb).was.called()
    end)

    it('should not invoke callback if run is not done', function()
        local rb = spy.new(function() return 123 end)
        local urb = spy.new(function() end)
        fake_response({ type = 'proc_start', data = { id = 999 } }, rb, urb)

        local cb = spy.new(function() end)
        fn.async.run('cmd', {'arg1', 'arg2'}, cb)

        -- Verify that our broadcast register was called, but that
        -- the unregister was not as the run is not done
        assert.spy(rb).was.called()
        assert.spy(urb).was.not_called()
        assert.spy(cb).was.not_called()
    end)

    it('should invoke the callback with exit code and no data when done if never received stdout/stderr', function()
        local cb, rb_cb
        local rb = spy.new(function(rb_cb_2)
            rb_cb = rb_cb_2
            return 123
        end)
        local urb = spy.new(function() end)
        stub_client(function(_, cb_2) cb = cb_2 end, rb, urb)

        -- Our callback should only occur once the process is done
        local done, wait = u.make_channel()
        fn.async.run('cmd', {'arg1', 'arg2'}, function(err, data)
            assert.is.falsy(err)
            assert.is.same({
                code = 456,
                stdout = {},
                stderr = {},
            }, data)

            done()
        end)

        -- Verify that our broadcast register was called and unregister
        -- has yet to be called
        assert.spy(rb).was.called()
        assert.spy(urb).was.not_called()

        -- Trigger the proc_start message
        cb({ type = 'proc_start', data = { id = 999 } })

        -- Verify that unregister still not triggered because not done
        assert.spy(urb).was.not_called()

        -- End the process
        rb_cb(
            { type = 'proc_done', data = { id = 999, code = 456 } },
            function() urb(123) end
        )

        -- Verify that after receiving a done message that the
        -- broadcast unregister was called
        assert.spy(urb).was.called_with(123)

        wait()
    end)

    it('should invoke the callback with exit code and data when done if received stdout/stderr', function()
        local cb, rb_cb
        local rb = spy.new(function(rb_cb_2)
            rb_cb = rb_cb_2
            return 123
        end)
        local urb = spy.new(function() end)
        stub_client(function(_, cb_2) cb = cb_2 end, rb, urb)

        -- Our callback should only occur once the process is done
        local done, wait = u.make_channel()
        fn.async.run('cmd', {'arg1', 'arg2'}, function(err, data)
            assert.is.falsy(err)
            assert.is.same({
                code = 456,
                stdout = {'abcdef'},
                stderr = {'ghijkl'},
            }, data)

            done()
        end)

        -- Verify that our broadcast register was called and unregister
        -- has yet to be called
        assert.spy(rb).was.called()
        assert.spy(urb).was.not_called()

        -- Trigger the proc_start message
        cb({ type = 'proc_start', data = { id = 999 } })

        -- Verify that unregister still not triggered because not done
        assert.spy(urb).was.not_called()

        -- Send stdout & stderr
        rb_cb({ type = 'proc_stdout', data = { id = 999, data = 'abc' } })
        rb_cb({ type = 'proc_stdout', data = { id = 999, data = 'def' } })
        rb_cb({ type = 'proc_stderr', data = { id = 999, data = 'ghi' } })
        rb_cb({ type = 'proc_stderr', data = { id = 999, data = 'jkl' } })

        -- stderr/stdout with wrong id is ignored
        rb_cb({ type = 'proc_stdout', data = { id = 123, data = 'bad' } })
        rb_cb({ type = 'proc_stderr', data = { id = 123, data = 'bad' } })

        -- end process with wrong id is ignored
        rb_cb({ type = 'proc_done', data = { id = 123, code = 'bad' } })

        -- Verify that unregister still not triggered because not done
        assert.spy(urb).was.not_called()

        -- End the process
        rb_cb(
            { type = 'proc_done', data = { id = 999, code = 456 } },
            function() urb(123) end
        )

        -- Verify that after receiving a done message that the
        -- broadcast unregister was called
        assert.spy(urb).was.called_with(123)

        wait()
    end)

    it('should invoke the callback with exit code and data when done received before start', function()
        local cb, rb_cb
        local rb = spy.new(function(rb_cb_2)
            rb_cb = rb_cb_2
            return 123
        end)
        local urb = spy.new(function() end)
        stub_client(function(_, cb_2) cb = cb_2 end, rb, urb)

        -- Our callback should only occur once the process is done
        local done, wait = u.make_channel()
        fn.async.run('cmd', {'arg1', 'arg2'}, function(err, data)
            assert.is.falsy(err)
            assert.is.same({
                code = 456,
                stdout = {'abcdef'},
                stderr = {'ghijkl'},
            }, data)

            done()
        end)

        -- Verify that our broadcast register was called and unregister
        -- has yet to be called
        assert.spy(rb).was.called()
        assert.spy(urb).was.not_called()

        -- Send stdout & stderr
        rb_cb({ type = 'proc_stdout', data = { id = 999, data = 'abc' } })
        rb_cb({ type = 'proc_stdout', data = { id = 999, data = 'def' } })
        rb_cb({ type = 'proc_stderr', data = { id = 999, data = 'ghi' } })
        rb_cb({ type = 'proc_stderr', data = { id = 999, data = 'jkl' } })

        -- stderr/stdout with wrong id is ignored
        rb_cb({ type = 'proc_stdout', data = { id = 123, data = 'bad' } })
        rb_cb({ type = 'proc_stderr', data = { id = 123, data = 'bad' } })

        -- end process with wrong id is ignored
        rb_cb({ type = 'proc_done', data = { id = 123, code = 'bad' } })

        -- Verify that unregister still not triggered because not done
        assert.spy(urb).was.not_called()

        -- End the process
        rb_cb(
            { type = 'proc_done', data = { id = 999, code = 456 } },
            function() end
        )

        -- Verify that unregister still not triggered because not start not received
        assert.spy(urb).was.not_called()

        -- Trigger the proc_start message
        cb({ type = 'proc_start', data = { id = 999 } })

        -- Verify that after receiving a done message that the
        -- broadcast unregister was called
        assert.spy(urb).was.called_with(123)

        wait()
    end)

    it('should invoke the callback with exit code and data when stdout/stderr received before start and done', function()
        local cb, rb_cb
        local rb = spy.new(function(rb_cb_2)
            rb_cb = rb_cb_2
            return 123
        end)
        local urb = spy.new(function() end)
        stub_client(function(_, cb_2) cb = cb_2 end, rb, urb)

        -- Our callback should only occur once the process is done
        local done, wait = u.make_channel()
        fn.async.run('cmd', {'arg1', 'arg2'}, function(err, data)
            assert.is.falsy(err)
            assert.is.same({
                code = 456,
                stdout = {'abcdef'},
                stderr = {'ghijkl'},
            }, data)

            done()
        end)

        -- Verify that our broadcast register was called and unregister
        -- has yet to be called
        assert.spy(rb).was.called()
        assert.spy(urb).was.not_called()

        -- Send stdout & stderr
        rb_cb({ type = 'proc_stdout', data = { id = 999, data = 'abc' } })
        rb_cb({ type = 'proc_stdout', data = { id = 999, data = 'def' } })
        rb_cb({ type = 'proc_stderr', data = { id = 999, data = 'ghi' } })
        rb_cb({ type = 'proc_stderr', data = { id = 999, data = 'jkl' } })

        -- stderr/stdout with wrong id is ignored
        rb_cb({ type = 'proc_stdout', data = { id = 123, data = 'bad' } })
        rb_cb({ type = 'proc_stderr', data = { id = 123, data = 'bad' } })

        -- Trigger the proc_start message
        cb({ type = 'proc_start', data = { id = 999 } })

        -- Verify that unregister still not triggered because not done
        assert.spy(urb).was.not_called()

        -- end process with wrong id is ignored
        rb_cb({ type = 'proc_done', data = { id = 123, code = 'bad' } })

        -- Verify that unregister still not triggered because not done
        assert.spy(urb).was.not_called()

        -- End the process
        rb_cb(
            { type = 'proc_done', data = { id = 999, code = 456 } },
            function() urb(123) end
        )

        -- Verify that after receiving a done message that the
        -- broadcast unregister was called
        assert.spy(urb).was.called_with(123)

        wait()
    end)

    it('should fill in exit code with -1 if exit_code is missing and success is falsy when proc done', function()
        local cb, rb_cb
        local rb = spy.new(function(rb_cb_2)
            rb_cb = rb_cb_2
            return 123
        end)
        stub_client(function(_, cb_2) cb = cb_2 end, rb, function() end)

        -- Our callback should only occur once the process is done
        local done, wait = u.make_channel()
        fn.async.run('cmd', {'arg1', 'arg2'}, function(err, data)
            assert.is.falsy(err)

            -- Exit code is -1 if success is falsy
            assert.is.same({
                code = -1,
                stdout = {},
                stderr = {},
            }, data)

            done()
        end)

        -- Trigger the proc_start message
        cb({ type = 'proc_start', data = { id = 999 } })

        -- End the process
        rb_cb(
            { type = 'proc_done', data = { id = 999 } },
            function() end
        )

        wait()
    end)

    it('should fill in exit code with 0 if exit_code is missing and success is truthy when proc done', function()
        local cb, rb_cb
        local rb = spy.new(function(rb_cb_2)
            rb_cb = rb_cb_2
            return 123
        end)
        stub_client(function(_, cb_2) cb = cb_2 end, rb, function() end)

        -- Our callback should only occur once the process is done
        local done, wait = u.make_channel()
        fn.async.run('cmd', {'arg1', 'arg2'}, function(err, data)
            assert.is.falsy(err)

            -- Exit code is 0 if success is truthy
            assert.is.same({
                code = 0,
                stdout = {},
                stderr = {},
            }, data)

            done()
        end)

        -- Trigger the proc_start message
        cb({ type = 'proc_start', data = { id = 999 } })

        -- End the process
        rb_cb(
            { type = 'proc_done', data = { id = 999, success = true } },
            function() end
        )

        wait()
    end)

    it('should invoke the callback with an error if nil received', function()
        local rb = spy.new(function() return 123 end)
        local urb = spy.new(function() end)
        fake_response(nil, rb, urb)

        local done, wait = u.make_channel()
        fn.async.run('cmd', {'arg1', 'arg2'}, function(err, data)
            assert.is.same('Nil response received', err)
            assert.is.falsy(data)
            done()
        end)

        -- Verify that our broadcast register was called and that the error
        -- properly unregistered it
        assert.spy(rb).was.called()
        assert.spy(urb).was.called_with(123)

        wait()
    end)

    it('should invoke the callback with an error if "error" type received', function()
        local rb = spy.new(function() return 123 end)
        local urb = spy.new(function() end)
        fake_response(
            { type = 'error', data = { description = 'some error msg' } },
            rb,
            urb
        )

        local done, wait = u.make_channel()
        fn.async.run('cmd', {'arg1', 'arg2'}, function(err, data)
            assert.is.same('some error msg', err)
            assert.is.falsy(data)
            done()
        end)

        -- Verify that our broadcast register was called and that the error
        -- properly unregistered it
        assert.spy(rb).was.called()
        assert.spy(urb).was.called_with(123)

        wait()
    end)

    it('should invoke the callback with an error if "error" type received without payload', function()
        local rb = spy.new(function() return 123 end)
        local urb = spy.new(function() end)
        fake_response({ type = 'error' }, rb, urb)

        local done, wait = u.make_channel()
        fn.async.run('cmd', {'arg1', 'arg2'}, function(err, data)
            assert.is.same('Error response received without data payload', err)
            assert.is.falsy(data)
            done()
        end)

        -- Verify that our broadcast register was called and that the error
        -- properly unregistered it
        assert.spy(rb).was.called()
        assert.spy(urb).was.called_with(123)

        wait()
    end)

    it('should invoke the callback with an error if "error" type received without description', function()
        local rb = spy.new(function() return 123 end)
        local urb = spy.new(function() end)
        fake_response({ type = 'error', data = {} }, rb, urb)

        local done, wait = u.make_channel()
        fn.async.run('cmd', {'arg1', 'arg2'}, function(err, data)
            assert.is.same('Error response received without description', err)
            assert.is.falsy(data)
            done()
        end)

        -- Verify that our broadcast register was called and that the error
        -- properly unregistered it
        assert.spy(rb).was.called()
        assert.spy(urb).was.called_with(123)

        wait()
    end)

    it('should invoke the callback with an error if not correct type received', function()
        local rb = spy.new(function() return 123 end)
        local urb = spy.new(function() end)
        fake_response({ type = 'other', data = {} }, rb, urb)

        local done, wait = u.make_channel()
        fn.async.run('cmd', {'arg1', 'arg2'}, function(err, data)
            assert.is.same('Received invalid response of type other', err)
            assert.is.falsy(data)
            done()
        end)

        -- Verify that our broadcast register was called and that the error
        -- properly unregistered it
        assert.spy(rb).was.called()
        assert.spy(urb).was.called_with(123)

        wait()
    end)
end)
