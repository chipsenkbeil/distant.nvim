local utils = require('distant-core.utils')

describe('distant-core.utils.strip_line_col', function()
    it('should return the input string if not ending with line and column', function()
        -- Has no line or column
        local str, line, col = utils.strip_line_col('distant://some/file.txt')
        assert.are.equal('distant://some/file.txt', str)
        assert.is_nil(line)
        assert.is_nil(col)

        -- Has a line and no column
        str, line, col = utils.strip_line_col('distant://some/file.txt:13')
        assert.are.equal('distant://some/file.txt:13', str)
        assert.is_nil(line)
        assert.is_nil(col)

        -- Has a line and no column
        str, line, col = utils.strip_line_col('distant://some/file.txt:13,')
        assert.are.equal('distant://some/file.txt:13,', str)
        assert.is_nil(line)
        assert.is_nil(col)

        -- Line is not a number
        str, line, col = utils.strip_line_col('distant://some/file.txt:abc,14')
        assert.are.equal('distant://some/file.txt:abc,14', str)
        assert.is_nil(line)
        assert.is_nil(col)

        -- Column is not a number
        str, line, col = utils.strip_line_col('distant://some/file.txt:13,abc')
        assert.are.equal('distant://some/file.txt:13,abc', str)
        assert.is_nil(line)
        assert.is_nil(col)
    end)

    it('should return input string without line/col suffix, line, and column when present', function()
        local str, line, col = utils.strip_line_col('distant://some/file.txt:13,14')
        assert.are.equal('distant://some/file.txt', str)
        assert.are.equal(13, line)
        assert.are.equal(14, col)
    end)
end)
