local u = require('distant.utils')

describe('utils', function()
    describe('build_arg_str', function()
        it('should fail if args is not a table', function()
            assert.has.errors(function()
                u.build_arg_str('text')
            end)
        end)

        it('should return an empty string if args is empty', function()
            assert.are.equal('', u.build_arg_str({}))
        end)

        it('should convert keys with value == true into --key', function()
            assert.are.equal('--key1', u.build_arg_str({
                key1 = true,
                key2 = false,
            }))
        end)

        it('should convert keys with value == string into --key value', function()
            assert.are.equal('--key1 some value', u.build_arg_str({
                key1 = 'some value',
                key2 = '',
            }))
        end)

        it('should convert keys with value == number into --key value', function()
            -- TODO: Is there a luassert way of doing this?
            local result = u.build_arg_str({
                key1 = 123,
                key2 = 0,
            })
            assert.is.truthy(
                (vim.startswith(result, '--key1 123') and vim.endswith(result, '--key2 0'))
                or
                (vim.startswith(result, '--key2 0') and vim.endswith(result, '--key1 123'))
            )
        end)

        it('should support excluding keys contained in the exclusion list', function()
            assert.are.equal('--key2 0', u.build_arg_str({
                key1 = 123,
                key2 = 0,
            }, { 'key1' }))
        end)
    end)

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
            assert.are.equal('', u.join_path())
        end)

        it('should return singular path as is', function()
            assert.are.equal('something', u.join_path('something'))
        end)

        it('should join separate paths using path sep', function()
            assert.are.equal('some/path/series', u.join_path('some', 'path', 'series'))
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
end)
