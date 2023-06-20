local Driver      = require('spec.e2e.driver')
local Destination = require('distant-core').Destination
local editor      = require('distant.editor')

describe('distant.editor.launch', function()
    --- @type spec.e2e.Driver
    local driver

    before_each(function()
        -- Configure to avoid setting up a client or manager
        -- as our test should verify that a manager and client
        -- are started automatically for us.
        driver = Driver:setup({
            label = 'distant.editor.launch',
            no_client = true,
            no_manager = true,

            -- Disable watching buffer content changes for our tests
            settings = {
                buffer = {
                    watch = {
                        enabled = false
                    }
                }
            },
        })
    end)

    after_each(function()
        -- Will remove all fixtures
        driver:teardown()
    end)

    it('should spawn a new server and establish a connection with it', function()
        -- Specialized format of manager://localhost to start it through the manager
        local destination = Destination:new({
            scheme = 'manager',
            host = 'localhost',
        })

        --- @type distant.core.Client|nil
        local client
        editor.launch({
            destination = destination,
            distant_args = '--shutdown lonely=10',
        }, function(err, c)
            assert(not err, err)
            client = assert(c)
        end)

        -- Wait for client to be ready
        local time = 1000 * 5
        assert(
            vim.wait(time, function() return client ~= nil end),
            string.format('No connection established after %.2fs', time / 1000.0)
        )

        -- Verify it works
        local err, info = assert(client):cached_system_info({})
        assert(not err, tostring(err))
        assert(info)
    end)
end)
