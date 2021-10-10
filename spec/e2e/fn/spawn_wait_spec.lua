local fn = require('distant.fn')
local Driver = require('spec.e2e.driver')

describe('fn', function()
    local driver

    before_each(function()
        driver = Driver:setup()
    end)

    after_each(function()
        driver:teardown()
    end)

    describe('spawn_wait', function()
        it('should execute remote program and return results', function()
            local err, res = fn.spawn_wait({cmd = 'printf', args = 'hello\non\nmultiple\nlines'})
            assert(not err, err)
            assert.are.same(res, {
                code = 0,
                stdout = {'hello', 'on', 'multiple', 'lines'},
                stderr = {},
            })
        end)

        it('should support capturing stderr', function()
            local err, res = fn.spawn_wait({cmd = 'sh', args = {'-c', '1>&2 printf "hello\non\nmultiple\nlines"'}})
            assert(not err, err)
            assert.are.same(res, {
                code = 0,
                stdout = {},
                stderr = {'hello', 'on', 'multiple', 'lines'},
            })
        end)

        it('should support capturing exit code', function()
            local err, res = fn.spawn_wait({cmd = 'sh', args = {'-c', 'exit 99'}})
            assert(not err, err)
            assert.are.same(res, {
                code = 99,
                stdout = {},
                stderr = {},
            })
        end)

        it('should fail if the remote program is not found', function()
            local err, res = fn.spawn_wait({cmd = 'idonotexist'})
            assert.is.truthy(err)
            assert.is.falsy(res)
        end)
    end)
end)
