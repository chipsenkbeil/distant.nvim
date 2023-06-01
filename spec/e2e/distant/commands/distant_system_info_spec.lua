local Driver = require('spec.e2e.driver')
local window = require('distant.ui.windows.main')

describe('distant.commands.DistantSystemInfo', function()
    --- @type spec.e2e.Driver
    local driver

    before_each(function()
        driver = Driver:setup({
            label = 'distant.commands.DistantSystemInfo',
        })
    end)

    after_each(function()
        -- Will remove all fixtures
        driver:teardown()
    end)

    it('should display system information in a dialog', function()
        -- :DistantSystemInfo
        vim.cmd('DistantSystemInfo')

        -- Wait a little bit to ensure that the window is open
        local ok = vim.wait(1000, function() return window:is_open() end, 100)
        assert(ok, 'Failed to open window')

        -- Verify we are on the correct view
        assert.are.equal('System Info', window:get_view())
    end)
end)
