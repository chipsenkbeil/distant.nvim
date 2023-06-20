local Driver      = require('spec.e2e.driver')
local Destination = require('distant-core').Destination
local editor      = require('distant.editor')
local Server      = require('distant-core').Server

describe('distant.editor.connect', function()
    --- @type spec.e2e.Driver
    local driver

    before_each(function()
        -- Configure to avoid setting up a client or manager
        -- as our test should verify that a manager and client
        -- are started automatically for us.
        driver = Driver:setup({
            label = 'distant.editor.connect',
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

    it('should establish a connection with the specified server', function()
        -- Spawn a server locally for us to connect to
        local server = Server:new({ binary = driver:cli_path() })
        local err, details = server:listen({
            shutdown = { key = 'lonely', value = 30 },
        })
        assert(not err, err)
        assert(details)

        -- Connect to the server
        local destination = Destination:new({
            scheme = 'distant',
            host = 'localhost',
            port = details.port,
            password = details.key,
        })

        --- @type distant.core.Client|nil
        local client
        editor.connect({ destination = destination }, function(err, c)
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

        -- Kill the server
        server:kill()
    end)
end)
