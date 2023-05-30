local plugin = require('distant')

describe('distant.buffer.parse_name', function()
    it('should parse "some/path" into { path }', function()
        local components = plugin.buf.parse_name('some/path')
        assert.are.same(components, {
            path = 'some/path',
        })
    end)

    it('should parse "scheme://some/path" into { scheme, path }', function()
        local components = plugin.buf.parse_name('scheme://some/path')
        assert.are.same(components, {
            scheme = 'scheme',
            path = 'some/path',
        })
    end)

    it('should parse "scheme+1234://some/path" into { scheme, connection, path }', function()
        local components = plugin.buf.parse_name('scheme+1234://some/path')
        assert.are.same(components, {
            scheme = 'scheme',
            connection = 1234,
            path = 'some/path',
        })
    end)

    it('should fail if connection is an invalid integer', function()
        local ok = pcall(plugin.buf.parse_name, 'scheme+conn://some/path')
        assert.is.falsy(ok)
    end)
end)
