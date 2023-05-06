local editor = require('distant.editor')

describe('distant.editor.open', function()
    it('should fail if given invalid input', function()
        assert.has.error(function()
            --- @diagnostic disable-next-line:param-type-mismatch
            editor.open(123)
        end)
    end)
end)
