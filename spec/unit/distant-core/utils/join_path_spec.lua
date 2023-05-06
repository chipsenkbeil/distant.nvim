local utils = require('distant-core.utils')

describe('distant-core.utils.join_path', function()
    it('should return empty string if no paths provided', function()
        assert.are.equal('', utils.join_path('/', {}))
    end)

    it('should return singular path as is', function()
        assert.are.equal('something', utils.join_path('/', { 'something' }))
    end)

    it('should join separate paths using path sep', function()
        assert.are.equal('some/path/series', utils.join_path('/', { 'some', 'path', 'series' }))
    end)
end)
