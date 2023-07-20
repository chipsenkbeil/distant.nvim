local plugin = require('distant')

describe('distant.setup', function()
    it('should split keys containing dots into nested tables', function()
        local settings = nil

        -- Stub out the actual setup logic
        --- @diagnostic disable-next-line
        plugin.__setup = function(_, _settings)
            settings = _settings
        end

        -- Create a setup where we have tables that exist
        -- before and after nested keys to ensure that
        -- creating new nested tables and injecting into
        -- existing nested tables work
        plugin:setup({
            -- This will get created from scratch
            ['path.to.key'] = 123,
            -- Create a table to be injected into
            other = {
                value = true
            },
            -- This will inject into an existing table
            ['other.path.to.key'] = {
                ['hello'] = 'world'
            },
            -- This will create a table, but it actually
            -- injects into the table coming after it in
            -- the list
            ['lazy.path.to.key'] = 'hello',
            -- Create a table that comes after injection,
            -- but still gets injected into
            lazy = {
                value = 456
            },
            -- Demonstrate that multiple nested keys
            -- can get merged together
            ['nested.key'] = 'abc',
            ['nested.key2'] = 789
        })

        assert.are.same(settings, {
            path = {
                to = {
                    key = 123,
                }
            },
            other = {
                path = {
                    to = {
                        key = {
                            hello = 'world'
                        }
                    }
                },
                value = true
            },
            lazy = {
                path = {
                    to = {
                        key = 'hello'
                    }
                },
                value = 456
            },
            nested = {
                key = 'abc',
                key2 = 789
            }
        })
    end)

    it('should fail to split keys containing dots if path includes a non-table value', function()
        -- Stub out the actual setup logic
        --- @diagnostic disable-next-line
        plugin.__setup = function()
        end

        -- Setup with a conflict that is not a table, so we cannot merge
        assert.has.error(function()
            plugin:setup({
                ['path.to.key'] = 123,
                path = {
                    to = 'hello'
                }
            })
        end)
    end)
end)
