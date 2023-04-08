local editor = require('distant.editor')

describe('editor.open', function()
    it('should fail if given invalid input', function()
        assert.has.error(function()
            editor.open(123)
        end)
    end)
end)
