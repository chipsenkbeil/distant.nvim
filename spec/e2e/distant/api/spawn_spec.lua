local plugin = require('distant')
local Driver = require('spec.e2e.driver')

describe('distant.api.spawn', function()
    --- @type spec.e2e.Driver
    local driver

    before_each(function()
        driver = Driver:setup({ label = 'distant.api.spawn' })
    end)

    after_each(function()
        driver:teardown()
    end)

    --- @param res distant.core.api.process.SpawnResults
    local function to_tbl(res)
        return {
            success = res.success,
            exit_code = res.exit_code,
            stdout = string.char(unpack(res.stdout)),
            stderr = string.char(unpack(res.stderr)),
        }
    end

    describe('synchronous', function()
        it('should execute remote program and return results synchronously if no callback provided', function()
            local err, res = plugin.api.spawn({ cmd = 'echo some output' })
            assert(not err, tostring(err))

            --- @cast res distant.core.api.process.SpawnResults
            assert(res)

            assert.are.same({
                success = true,
                exit_code = 0,
                stdout = 'some output\n',
                stderr = '',
            }, to_tbl(res))
        end)

        it('should support capturing stderr', function()
            local err, res = plugin.api.spawn({ cmd = 'sh -c "echo some output 1>&2"' })
            assert(not err, tostring(err))

            --- @cast res distant.core.api.process.SpawnResults
            assert(res)

            assert.are.same({
                success = true,
                exit_code = 0,
                stdout = '',
                stderr = 'some output\n',
            }, to_tbl(res))
        end)
    end)

    describe('asynchronous', function()
        it('should execute remote program and return process if callback provided', function()
            --- @type distant.core.api.process.SpawnResults|nil
            local results

            local err, process = plugin.api.spawn({ cmd = 'echo some output' }, function(err, res)
                assert(not err, tostring(err))
                results = res
            end)
            assert(not err, tostring(err))

            --- @cast process distant.core.api.Process
            assert(process)

            local ok = vim.wait(1000, function() return process:is_done() end, 100)
            assert.is.truthy(ok)
            assert(results, 'Process results not acquired')

            assert.are.equal(true, process:is_success())
            assert.are.equal(0, process:exit_code())
            assert.are.same({}, process:stdout())
            assert.are.same({}, process:stderr())

            assert.are.same({
                success = true,
                exit_code = 0,
                stdout = 'some output\n',
                stderr = '',
            }, to_tbl(results))
        end)
    end)
end)
