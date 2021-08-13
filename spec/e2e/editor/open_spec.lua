local c = require('spec.e2e.config')
local editor = require('distant.editor')
local fn = require('distant.fn')
local u = require('spec.e2e.utils')

describe('editor.open', function()
   before_each(function()
      -- u.print_config()
      u.setup_session()
   end)

   it('should open a file and set appropriate configuration', function()
      local path = 'spec/e2e/fixtures/test.txt'
      editor.open(path)

      local buf = vim.api.nvim_get_current_buf()

      -- Read the contents of the buffer that should have been populated
      local buf_lines = vim.fn.getbufline(buf, 1, '$')
      assert.are.same({
         'This is a file used for tests',
         'with multiple lines of text.',
         '',
      }, buf_lines)

      -- Get the absolute path to the file we are editing
      local err, metadata = fn.metadata(path, {canonicalize = true})
      assert(not err, err)

      -- Verify we set a remote path variable to the absolute path
      local remote_path = vim.api.nvim_buf_get_var(buf, 'distant_remote_path')
      assert.are.equal(
         metadata.canonicalized_path,
         remote_path
      )

      -- Verify we set file-specific buffer properties
      assert.are.equal(remote_path, vim.api.nvim_buf_get_name(buf))
      assert.are.equal('text', vim.api.nvim_buf_get_option(buf, 'filetype'))
      assert.are.equal('acwrite', vim.api.nvim_buf_get_option(buf, 'buftype'))

      -- Verify we switched our window to the current buffer
      assert.are.equal(buf, vim.api.nvim_win_get_buf(0))
   end)

   it('should configure file buffers to send contents to remote server on write', function()
      local path = 'spec/e2e/fixtures/test.txt'
      editor.open(path)

      -- Change the buffer and write it back to the remote destination
      local buf = vim.api.nvim_get_current_buf()
      vim.api.nvim_buf_set_lines(buf, 0, vim.api.nvim_buf_line_count(buf), true, {'line 1', 'line 2'})
      vim.cmd([[write]])

      -- Verify that the local file didn't change
      assert.are.same(table.concat({
         'This is a file used for tests',
         'with multiple lines of text.',
         '',
      }, '\n'), u.read_local_file(path))

      -- Verify that the remote file did change
      assert.are.same(table.concat({
         'line 1',
         'line 2',
      }, '\n'), u.read_remote_file(c.root_dir .. '/' .. path))
   end)

   it('should configure file buffers to reload contents from remote server on edit', function()
      -- todo: need utils.write_remote_file that will scp a remote file from a temporary
      --       local location to somewhere on the remote
      assert(false, 'todo')
   end)

   it('should configure file buffers to remove autocmd callbacks on delete', function()
      assert(false, 'todo')
   end)

   it('should apply file mappings if opening a file and have mappings defined', function()
      assert(false, 'todo')
   end)

   it('should apply file mappings if opening a file and have mappings defined', function()
      assert(false, 'todo')
   end)
end)
