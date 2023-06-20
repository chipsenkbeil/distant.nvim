local plugin = require('distant')
local Driver = require('spec.e2e.driver')

describe('distant.api.watch', function()
    --- @type spec.e2e.Driver, spec.e2e.RemoteDir
    local driver, root

    before_each(function()
        driver = Driver:setup({ label = 'distant.api.watch' })
        root = driver:new_dir_fixture()
    end)

    after_each(function()
        driver:teardown()
    end)

    describe('asynchronous', function()
        it('should be able to watch for single file changes', function()
            local file = root:file()
            assert(file:touch(), 'Failed to create file: ' .. file:path())

            driver:debug_print('Watching ' .. file:path())
            local capture = driver:new_capture()
            --- @diagnostic disable-next-line:param-type-mismatch
            plugin.api.watch({ path = file:path() }, capture)

            -- Wait a bit to be ready for conducting a change
            vim.wait(100)

            -- Update the file
            file:write('some text')

            --- @type distant.core.api.Error|nil, distant.core.api.Watcher|nil
            local err, watcher = capture.wait()
            assert(not err, vim.inspect(err))

            capture = driver:new_capture()
            --- @diagnostic disable-next-line:param-type-mismatch
            assert(watcher):on_change(capture)

            local change = capture.wait()
            assert(not err, vim.inspect(err))
            assert.is.truthy(change)
        end)

        it('should be able to watch recursively for changes in a directory', function()
            local file = root:file()
            assert(file:touch(), 'Failed to create file: ' .. file:path())

            driver:debug_print('Watching ' .. root:path())
            local capture = driver:new_capture()
            --- @diagnostic disable-next-line:param-type-mismatch
            plugin.api.watch({ path = root:path(), recursive = true }, capture)

            -- Wait a bit to be ready for conducting a change
            vim.wait(100)

            -- Update the file
            file:write('some text')

            --- @type distant.core.api.Error|nil, distant.core.api.Watcher|nil
            local err, watcher = capture.wait()
            assert(not err, vim.inspect(err))

            capture = driver:new_capture()
            --- @diagnostic disable-next-line:param-type-mismatch
            assert(watcher):on_change(capture)

            local change = capture.wait()
            assert(not err, vim.inspect(err))
            assert.is.truthy(change)
        end)

        it('should be able to stop watching by calling unwatch', function()
            local file = root:file()
            assert(file:touch(), 'Failed to create file: ' .. file:path())

            --
            -- Watch the file
            --

            -- NOTE: We get this path because unwatching needs to have matching
            --       paths and isn't handling non-canonicalized well.
            local path = assert(file:canonicalized_path())

            local changes = {}

            driver:debug_print('Watching ' .. path)
            --- @diagnostic disable-next-line:param-type-mismatch
            plugin.api.watch({ path = path, recursive = true }, function(err, watcher)
                assert(not err, vim.inspect(err))
                assert(watcher):on_change(function(change)
                    table.insert(changes, change)
                end)
            end)

            -- Wait a bit to be ready for conducting a change
            vim.wait(100)
            changes = {}

            -- Send something so we can get confirmation that it's working
            file:write('some text')
            assert(vim.wait(1000, function() return not vim.tbl_isempty(changes) end), 'Watch failed')

            --
            -- Unwatch the file
            --

            driver:debug_print('Unwatching ' .. path)
            local capture = driver:new_capture()
            --- @diagnostic disable-next-line:param-type-mismatch
            plugin.api.unwatch({ path = path }, capture)

            local err, res = capture.wait()
            assert(not err, vim.inspect(err))
            assert(res)
            assert.are.equal(res.type, 'ok')

            -- Clear tracked changes
            changes = {}

            --
            -- Verify not watched anymore
            --

            -- Update the file
            file:write('some text')

            -- Wait 300 milliseconds for a response
            vim.wait(300)

            driver:debug_print('Asserting no more changes were received for ' .. path)
            assert(vim.tbl_isempty(changes), 'Still got changes: ' .. vim.inspect(changes))
        end)
    end)
end)
