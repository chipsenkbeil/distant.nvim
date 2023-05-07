local fn = require('distant.fn')
local Driver = require('spec.e2e.driver')

describe('distant.fn', function()
    --- @type spec.e2e.Driver
    local driver

    before_each(function()
        driver = Driver:setup({ label = 'distant.fn.spawn' })
    end)

    after_each(function()
        driver:teardown()
    end)

    describe('spawn', function()
        --- @param res distant.client.api.process.SpawnResults
        local function to_tbl(res)
            return {
                success = res.success,
                exit_code = res.exit_code,
                stdout = string.char(unpack(res.stdout)),
                stderr = string.char(unpack(res.stderr)),
            }
        end

        it('should execute remote program and return results synchronously if no callback provided', function()
            local err, res = fn.spawn({ cmd = 'echo some output' })
            assert(not err, tostring(err))

            --- @cast res distant.client.api.process.SpawnResults
            assert(res)

            assert.are.same({
                success = true,
                exit_code = 0,
                stdout = 'some output\n',
                stderr = '',
            }, to_tbl(res))
        end)

        it('should execute remote program and return process if callback provided', function()
            --- @type distant.client.api.process.SpawnResults|nil
            local results

            local err, process = fn.spawn({ cmd = 'echo some output' }, function(err, res)
                assert(not err, tostring(err))
                results = res
            end)
            assert(not err, tostring(err))

            --- @cast process distant.client.api.Process
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

        -- distant and ssh modes behave differently here as ssh treats as a success and
        -- echoes out that the process does not exist whereas distant clearly marks
        -- as an error
        --
        -- TODO: For some reason, stderr is also not captured in the test below. distant-ssh2
        --       is able to correctly capture stderr, so this will need to be investigated
        if driver:mode() == 'distant' then
            it('should support capturing stderr', function()
                local err, res = fn.spawn({ cmd = 'sh -c "echo some output 1>&2"' })
                assert(not err, tostring(err))

                --- @cast res distant.client.api.process.SpawnResults
                assert(res)

                assert.are.same({
                    success = true,
                    exit_code = 0,
                    stdout = '',
                    stderr = 'some output\n',
                }, to_tbl(res))
            end)

            it('should support capturing exit code', function()
                local err, res = fn.spawn({ cmd = 'sh -c "exit 99"' })
                assert(not err, tostring(err))

                --- @cast res distant.client.api.process.SpawnResults
                assert(res)

                assert.are.same({
                    success = false,
                    exit_code = 99,
                    stdout = '',
                    stderr = '',
                }, to_tbl(res))
            end)
        end
    end)
end)
