local editor = require('distant.editor')
local u = require('spec.e2e.utils')

describe('editor.open', function()
   before_each(function()
      u.print_config()
      u.setup_session()
   end)

   it('should open a file and set appropriate configuration', function()
      editor.open('spec/e2e/fixtures/test.txt')

      local buf_lines = vim.fn.getbufline('%', 1, '$')
      assert.are.same({
         'This is a file used for tests',
         'with multiple lines of text.',
         '',
      }, buf_lines)
   end)
end)
