local c = require('spec.e2e.config')
local u = require('spec.e2e.driver.utils')

--- Provides helpers related to test files and other fixtures
local fixtures = {}

local function random_remote_file_name(ext)
   assert(type(ext) == 'string', 'ext must be a string')
   return 'test-file-' .. math.floor(math.random() * 10000) .. '.' .. ext
end

--- Returns list of lines for fixture text file
fixtures.text_lines = function()
   return {
      'This is a file used for tests',
      'with multiple lines of text.',
   }
end

--- Create a new test text file remotely and return the path to it
fixtures.make_text_file = function()
   -- TODO: Support real path
   local path = '/tmp/' .. random_remote_file_name('txt')
   u.write_remote_file(path, table.concat(fixtures.text_lines(), '\n'))
   return path
end

--- Removes a remove test file
fixtures.remove_test_file = function(path)
   local out = vim.fn.system({'ssh', '-p', c.port, c.host, 'rm', '-f', path})
   local errno = tonumber(vim.v.shell_error)
   assert(errno == 0, 'ssh rm failed (' .. errno .. '): ' .. out)
end

return fixtures
