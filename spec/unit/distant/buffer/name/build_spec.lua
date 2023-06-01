local plugin = require('distant')

describe('distant.buffer.name.build', function()
    it('should fail if an invalid format is specified', function()
        local ok = pcall(plugin.buf.name.build, {
            --- @diagnostic disable-next-line:assign-type-mismatch
            format = 'invalid',
            path = 'some/path',
        })
        assert.is.falsy(ok)
    end)

    describe('format=modern', function()
        it('should fail if an invalid scheme is specified', function()
            local ok = pcall(plugin.buf.name.build, {
                format = 'modern',
                path = 'some/path',
                scheme = 'sche_me',
            })
            assert.is.falsy(ok)
        end)

        it('should return the path if no scheme or connection provided', function()
            local name = plugin.buf.name.build({
                format = 'modern',
                path = 'some/path',
            })
            assert.equal(name, 'some/path')
        end)

        it('should return scheme://path if those values provided', function()
            local name = plugin.buf.name.build({
                format = 'modern',
                path = 'some/path',
                scheme = 'scheme',
            })
            assert.equal(name, 'scheme://some/path')
        end)

        it('should return scheme+connection://path if those values provided', function()
            local name = plugin.buf.name.build({
                connection = 1234,
                format = 'modern',
                path = 'some/path',
                scheme = 'scheme',
            })
            assert.equal(name, 'scheme+1234://some/path')
        end)

        it('should return path if connection provided but not scheme', function()
            local name = plugin.buf.name.build({
                connection = 1234,
                format = 'modern',
                path = 'some/path',
            })
            assert.equal(name, 'some/path')
        end)
    end)

    describe('format=legacy', function()
        it('should fail if an invalid scheme is specified', function()
            local ok = pcall(plugin.buf.name.build, {
                format = 'legacy',
                path = 'some/path',
                scheme = 'sche_me',
            })
            assert.is.falsy(ok)
        end)

        it('should return the path if no scheme or connection provided', function()
            local name = plugin.buf.name.build({
                format = 'legacy',
                path = 'some/path'
            })
            assert.equal(name, 'some/path')
        end)

        it('should return scheme://path if those values provided', function()
            local name = plugin.buf.name.build({
                format = 'legacy',
                path = 'some/path',
                scheme = 'scheme',
            })
            assert.equal(name, 'scheme://some/path')
        end)

        it('should return scheme://connection://path if those values provided', function()
            local name = plugin.buf.name.build({
                connection = 1234,
                format = 'legacy',
                path = 'some/path',
                scheme = 'scheme',
            })
            assert.equal(name, 'scheme://1234://some/path')
        end)

        it('should return path if connection provided but not scheme', function()
            local name = plugin.buf.name.build({
                connection = 1234,
                format = 'legacy',
                path = 'some/path'
            })
            assert.equal(name, 'some/path')
        end)
    end)
end)
