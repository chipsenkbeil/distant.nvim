local editor = require('distant.editor')

describe('editor.open', function()
   it('should fail is path is not a string', function()
      assert.has.error(function()
         editor.open(123)
      end, 'path must be a string')
   end)
 end)
