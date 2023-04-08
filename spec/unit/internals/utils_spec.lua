local u = require('distant-core.utils')

describe('utils', function()
    describe('clean_term_line', function()
        it('should remove carriage return characters', function()
            assert.are.equal('sometext', u.clean_term_line('some\rtext'))
        end)

        it('should remove escape sequences in the form ^[1;31m', function()
            -- \x1b is ^[ and we need to test ^[NN;NN;NNm and ^[NN;NN;NNK
            assert.are.equal('sometext', u.clean_term_line('some\x1b[1mtext'))
            assert.are.equal('sometext', u.clean_term_line('some\x1b[12mtext'))
            assert.are.equal('sometext', u.clean_term_line('some\x1b[1;1mtext'))
            assert.are.equal('sometext', u.clean_term_line('some\x1b[1;12mtext'))
            assert.are.equal('sometext', u.clean_term_line('some\x1b[12;1mtext'))
            assert.are.equal('sometext', u.clean_term_line('some\x1b[12;12mtext'))
            assert.are.equal('sometext', u.clean_term_line('some\x1b[1;1;1mtext'))
            assert.are.equal('sometext', u.clean_term_line('some\x1b[12;1;1mtext'))
            assert.are.equal('sometext', u.clean_term_line('some\x1b[1;12;1mtext'))
            assert.are.equal('sometext', u.clean_term_line('some\x1b[1;1;12mtext'))
            assert.are.equal('sometext', u.clean_term_line('some\x1b[1;12;12mtext'))
            assert.are.equal('sometext', u.clean_term_line('some\x1b[12;1;12mtext'))
            assert.are.equal('sometext', u.clean_term_line('some\x1b[12;12;12mtext'))

            assert.are.equal('sometext', u.clean_term_line('some\x1b[1Ktext'))
            assert.are.equal('sometext', u.clean_term_line('some\x1b[12Ktext'))
            assert.are.equal('sometext', u.clean_term_line('some\x1b[1;1Ktext'))
            assert.are.equal('sometext', u.clean_term_line('some\x1b[1;12Ktext'))
            assert.are.equal('sometext', u.clean_term_line('some\x1b[12;1Ktext'))
            assert.are.equal('sometext', u.clean_term_line('some\x1b[12;12Ktext'))
            assert.are.equal('sometext', u.clean_term_line('some\x1b[1;1;1Ktext'))
            assert.are.equal('sometext', u.clean_term_line('some\x1b[12;1;1Ktext'))
            assert.are.equal('sometext', u.clean_term_line('some\x1b[1;12;1Ktext'))
            assert.are.equal('sometext', u.clean_term_line('some\x1b[1;1;12Ktext'))
            assert.are.equal('sometext', u.clean_term_line('some\x1b[1;12;12Ktext'))
            assert.are.equal('sometext', u.clean_term_line('some\x1b[12;1;12Ktext'))
            assert.are.equal('sometext', u.clean_term_line('some\x1b[12;12;12Ktext'))
        end)
    end)

    describe('parent_path', function()
        it('should return nil if provided root path', function()
            assert.is.falsy(u.parent_path('/'))
        end)

        it('should return nil if provided single relative component', function()
            assert.is.falsy(u.parent_path('something'))
        end)

        it('should return parent path by removing last component', function()
            -- Absolute paths
            assert.are.equal('/some/', u.parent_path('/some/path'))
            assert.are.equal('/some/', u.parent_path('/some/path.txt'))
            assert.are.equal('/some/', u.parent_path('/some/path.txt.ext'))
            assert.are.equal('/some/path/', u.parent_path('/some/path/file.txt.ext'))

            -- Relative paths
            assert.are.equal('some/', u.parent_path('some/path'))
            assert.are.equal('some/', u.parent_path('some/path.txt'))
            assert.are.equal('some/', u.parent_path('some/path.txt.ext'))
            assert.are.equal('some/path/', u.parent_path('some/path/file.txt.ext'))
        end)
    end)

    describe('join_path', function()
        it('should return empty string if no paths provided', function()
            assert.are.equal('', u.join_path('/', {}))
        end)

        it('should return singular path as is', function()
            assert.are.equal('something', u.join_path('/', { 'something' }))
        end)

        it('should join separate paths using path sep', function()
            assert.are.equal('some/path/series', u.join_path('/', { 'some', 'path', 'series' }))
        end)
    end)

    describe('oneshot_channel', function()
        it('should fail if timeout or interval are not numbers', function()
            assert.has.errors(function()
                u.oneshot_channel(0, 'not a number')
            end)

            assert.has.errors(function()
                u.oneshot_channel('not a number', 0)
            end)
        end)

        it('should return tx, rx such that rx returns whatever tx passes it', function()
            local tx, rx = u.oneshot_channel(100, 10)
            tx(1, 2, 3)
            local err, a, b, c = rx()
            assert.is.falsy(err)
            assert.are.equal(1, a)
            assert.are.equal(2, b)
            assert.are.equal(3, c)
        end)

        it('should return tx, rx such that rx returns an error if the timeout is reached', function()
            local _, rx = u.oneshot_channel(10, 1)
            local err, result = rx()
            assert.are.equal('Timeout of 10 exceeded!', err)
            assert.is.falsy(result)
        end)
    end)

    describe('strip_line_col', function()
        it('should return the input string if not ending with line and column', function()
            -- Has no line or column
            local str, line, col = u.strip_line_col('distant://some/file.txt')
            assert.are.equal('distant://some/file.txt', str)
            assert.is.falsy(line)
            assert.is.falsy(col)

            -- Has a line and no column
            str, line, col = u.strip_line_col('distant://some/file.txt:13')
            assert.are.equal('distant://some/file.txt:13', str)
            assert.is.falsy(line)
            assert.is.falsy(col)

            -- Has a line and no column
            str, line, col = u.strip_line_col('distant://some/file.txt:13,')
            assert.are.equal('distant://some/file.txt:13,', str)
            assert.is.falsy(line)
            assert.is.falsy(col)

            -- Line is not a number
            str, line, col = u.strip_line_col('distant://some/file.txt:abc,14')
            assert.are.equal('distant://some/file.txt:abc,14', str)
            assert.is.falsy(line)
            assert.is.falsy(col)

            -- Column is not a number
            str, line, col = u.strip_line_col('distant://some/file.txt:13,abc')
            assert.are.equal('distant://some/file.txt:13,abc', str)
            assert.is.falsy(line)
            assert.is.falsy(col)
        end)

        it('should return input string without line/col suffix, line, and column when present', function()
            local str, line, col = u.strip_line_col('distant://some/file.txt:13,14')
            assert.are.equal('distant://some/file.txt', str)
            assert.are.equal(13, line)
            assert.are.equal(14, col)
        end)
    end)

    describe('parse_destination', function()
        it('should support parsing just a host', function()
            local d = u.parse_destination('some.destination')

            assert.are.same({
                scheme = nil,
                username = nil,
                password = nil,
                host = 'some.destination',
                port = nil,
            }, d)
        end)

        it('should support parsing a host & port', function()
            local d = u.parse_destination('some.destination:1234')

            assert.are.same({
                scheme = nil,
                username = nil,
                password = nil,
                host = 'some.destination',
                port = 1234,
            }, d)
        end)

        it('should support parsing a scheme & host', function()
            local d = u.parse_destination('scheme://some.destination')

            assert.are.same({
                scheme = 'scheme',
                username = nil,
                password = nil,
                host = 'some.destination',
                port = nil,
            }, d)
        end)

        it('should support parsing a username & host', function()
            local d = u.parse_destination('username@some.destination')

            assert.are.same({
                scheme = nil,
                username = 'username',
                password = nil,
                host = 'some.destination',
                port = nil,
            }, d)
        end)

        it('should support parsing a password & host', function()
            local d = u.parse_destination(':password@some.destination')

            assert.are.same({
                scheme = nil,
                username = nil,
                password = 'password',
                host = 'some.destination',
                port = nil,
            }, d)
        end)

        it('should support parsing a username & password & host', function()
            local d = u.parse_destination('username:password@some.destination')

            assert.are.same({
                scheme = nil,
                username = 'username',
                password = 'password',
                host = 'some.destination',
                port = nil,
            }, d)
        end)

        it('should support parsing a scheme & username & password & host', function()
            local d = u.parse_destination('scheme://username:password@some.destination')

            assert.are.same({
                scheme = 'scheme',
                username = 'username',
                password = 'password',
                host = 'some.destination',
                port = nil,
            }, d)
        end)

        it('should support parsing a username & password & host & port', function()
            local d = u.parse_destination('username:password@some.destination:1234')

            assert.are.same({
                scheme = nil,
                username = 'username',
                password = 'password',
                host = 'some.destination',
                port = 1234,
            }, d)
        end)

        it('should support parsing a scheme & username & password & host & port', function()
            local d = u.parse_destination('scheme://username:password@some.destination:1234')

            assert.are.same({
                scheme = 'scheme',
                username = 'username',
                password = 'password',
                host = 'some.destination',
                port = 1234,
            }, d)
        end)

        it('should yield nil if the destination is invalid', function()
            local d = u.parse_destination('')
            assert.is.falsy(d)

            local d = u.parse_destination('scheme://')
            assert.is.falsy(d)

            local d = u.parse_destination(':')
            assert.is.falsy(d)

            local d = u.parse_destination('@')
            assert.is.falsy(d)

            local d = u.parse_destination('username@')
            assert.is.falsy(d)

            local d = u.parse_destination(':password@')
            assert.is.falsy(d)

            local d = u.parse_destination(':1234')
            assert.is.falsy(d)

            local d = u.parse_destination('some.destination:asdf')
            assert.is.falsy(d)
        end)
    end)
end)
