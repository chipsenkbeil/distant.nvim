local plugin = require('distant')

describe('distant.buffer.build_name', function()
    it('should return the path if no scheme or connection provided', function()
        local name = plugin.buf.build_name({
            path = 'some/path'
        })
        assert.equal(name, 'some/path')
    end)

    it('should return scheme://path if those values provided', function()
        local name = plugin.buf.build_name({
            scheme = 'scheme',
            path = 'some/path'
        })
        assert.equal(name, 'scheme://some/path')
    end)

    it('should return scheme+connection://path if those values provided', function()
        local name = plugin.buf.build_name({
            scheme = 'scheme',
            connection = 1234,
            path = 'some/path'
        })
        assert.equal(name, 'scheme+1234://some/path')
    end)

    it('should return path if connection provided but not scheme', function()
        local name = plugin.buf.build_name({
            connection = 1234,
            path = 'some/path'
        })
        assert.equal(name, 'some/path')
    end)
end)
