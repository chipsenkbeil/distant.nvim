local Driver = require('spec.e2e.driver')

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

        error('TODO: Implement new display format')
    end)
end)
