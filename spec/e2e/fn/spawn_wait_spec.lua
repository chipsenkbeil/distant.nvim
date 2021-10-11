local fn = require('distant.fn')
local Driver = require('spec.e2e.driver')

describe('fn', function()
    local driver

    before_each(function()
        driver = Driver:setup({
            log_file = '/tmp/spawn_wait.log',
            log_level = 'trace',
        })
    end)

    after_each(function()
        driver:teardown()
    end)

    describe('spawn_wait', function()
        local function to_tbl(res)
            return {
                success = res.success,
                exit_code = res.exit_code,
                stdout = res.stdout,
                stderr = res.stderr,
            }
        end

        it('should execute remote program and return results', function()
            local err, res = fn.spawn_wait({cmd = 'printf', args = {'hello\non\nmultiple\nlines'}})
            assert(not err, err)
            assert.are.same(to_tbl(res), {
                success = true,
                exit_code = 0,
                stdout = 'hello\non\nmultiple\nlines',
                stderr = '',
            })
        end)

        it('should support capturing stderr', function()
            local err, res = fn.spawn_wait({cmd = 'sh', args = {'-c', '1>&2 printf "hello\non\nmultiple\nlines"'}})
            assert(not err, err)
            assert.are.same(to_tbl(res), {
                success = true,
                exit_code = 0,
                stdout = '',
                stderr = 'hello\non\nmultiple\nlines',
            })
        end)

        it('should support capturing exit code', function()
            local err, res = fn.spawn_wait({cmd = 'sh', args = {'-c', 'exit 99'}})
            assert(not err, err)
            assert.are.same(to_tbl(res), {
                success = false,
                exit_code = 99,
                stdout = '',
                stderr = '',
            })
        end)

        it('should fail if the remote program is not found', function()
            local err, res = fn.spawn_wait({cmd = 'idonotexist'})
            assert.is.truthy(err)
            assert.is.falsy(res)
        end)
    end)
end)
