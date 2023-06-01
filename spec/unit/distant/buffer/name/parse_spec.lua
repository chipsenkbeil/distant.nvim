local plugin = require('distant')

describe('distant.buffer.name.parse', function()
    it('should fail if an invalid format is specified', function()
        local ok = pcall(plugin.buf.name.parse, {
            --- @diagnostic disable-next-line:assign-type-mismatch
            format = 'invalid',
            name = 'some/path',
        })
        assert.is.falsy(ok)
    end)

    describe('format=modern', function()
        it('should fail if connection is an invalid integer', function()
            local ok = pcall(plugin.buf.name.parse, {
                format = 'modern',
                name = 'scheme+conn://some/path',
            })
            assert.is.falsy(ok)
        end)

        it('should fail if scheme is invalid', function()
            local ok = pcall(plugin.buf.name.parse, {
                format = 'modern',
                name = 'sche_me://some/path',
            })
            assert.is.falsy(ok)
        end)

        it('should parse "some/path" into { path }', function()
            local components = plugin.buf.name.parse({
                format = 'modern',
                name = 'some/path',
            })
            assert.are.same(components, {
                path = 'some/path',
            })
        end)

        it('should parse "scheme://some/path" into { scheme, path }', function()
            local components = plugin.buf.name.parse({
                format = 'modern',
                name = 'scheme://some/path',
            })
            assert.are.same(components, {
                scheme = 'scheme',
                path = 'some/path',
            })
        end)

        it('should parse "scheme+1234://some/path" into { scheme, connection, path }', function()
            local components = plugin.buf.name.parse({
                format = 'modern',
                name = 'scheme+1234://some/path',
            })
            assert.are.same(components, {
                scheme = 'scheme',
                connection = 1234,
                path = 'some/path',
            })
        end)
    end)

    describe('format=legacy', function()
        it('should fail if connection is an invalid integer', function()
            local ok = pcall(plugin.buf.name.parse, {
                format = 'legacy',
                name = 'scheme://conn://some/path',
            })
            assert.is.falsy(ok)
        end)

        it('should fail if scheme is invalid', function()
            local ok = pcall(plugin.buf.name.parse, {
                format = 'legacy',
                name = 'sche_me://some/path',
            })
            assert.is.falsy(ok)
        end)

        it('should parse "some/path" into { path }', function()
            local components = plugin.buf.name.parse({
                format = 'legacy',
                name = 'some/path',
            })
            assert.are.same(components, {
                path = 'some/path',
            })
        end)

        it('should parse "scheme://some/path" into { scheme, path }', function()
            local components = plugin.buf.name.parse({
                format = 'legacy',
                name = 'scheme://some/path',
            })
            assert.are.same(components, {
                scheme = 'scheme',
                path = 'some/path',
            })
        end)

        it('should parse "scheme://1234://some/path" into { scheme, connection, path }', function()
            local components = plugin.buf.name.parse({
                format = 'legacy',
                name = 'scheme://1234://some/path',
            })
            assert.are.same(components, {
                scheme = 'scheme',
                connection = 1234,
                path = 'some/path',
            })
        end)
    end)
end)
