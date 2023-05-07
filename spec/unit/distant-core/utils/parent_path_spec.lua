local utils = require('distant-core.utils')

describe('distant-core.utils.parent_path', function()
    it('should return nil if provided root path', function()
        assert.is_nil(utils.parent_path('/'))
    end)

    it('should return nil if provided single relative component', function()
        assert.is_nil(utils.parent_path('something'))
    end)

    it('should return parent path by removing last component', function()
        -- Absolute paths
        assert.are.equal('/some/', utils.parent_path('/some/path'))
        assert.are.equal('/some/', utils.parent_path('/some/path.txt'))
        assert.are.equal('/some/', utils.parent_path('/some/path.txt.ext'))
        assert.are.equal('/some/path/', utils.parent_path('/some/path/file.txt.ext'))

        -- Relative paths
        assert.are.equal('some/', utils.parent_path('some/path'))
        assert.are.equal('some/', utils.parent_path('some/path.txt'))
        assert.are.equal('some/', utils.parent_path('some/path.txt.ext'))
        assert.are.equal('some/path/', utils.parent_path('some/path/file.txt.ext'))
    end)
end)
