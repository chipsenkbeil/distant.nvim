local editor = require('distant.editor')
local plugin = require('distant')
local match  = require('luassert.match')
local stub   = require('luassert.stub')

describe('distant.editor.write', function()
    it('should do nothing if the buffer does not have a remote path', function()
        local result = editor.write({ buf = 123 })
        assert.equal(result, false)
    end)

    it('should write all lines of the buffer to the remote file', function()
        local path = 'some/path'
        local contents = 'some lines\nof text\nfor a file'
        local content_lines = vim.split(contents, '\n', { plain = true })
        local opts = { a = 3, b = 'test' }

        local remote_path_get = stub_vars_buf_remote_path_get(path)
        stub(plugin.api, 'write_file_text', false, true)
        stub(vim.fn, 'getbufline', content_lines)
        stub(vim.api, 'nvim_buf_set_option')

        editor.write(vim.tbl_extend('keep', { buf = 123 }, opts))

        local _ = match._
        assert.stub(remote_path_get).was.called_with(123)
        assert.stub(vim.fn.getbufline).was.called_with(123, _, _)
        assert.stub(plugin.api.write_file_text).was.called_with({
            path = path,
            text = contents,
            buf = 123,
            a = 3,
            b = 'test',
        })
        assert.stub(vim.api.nvim_buf_set_option).was.called_with(123, 'modified', false)
    end)

    it('should not reset the modified flag if unsuccessful', function()
        local path = 'some/path'
        local contents = 'some lines\nof text\nfor a file'
        local content_lines = vim.split(contents, '\n', { plain = true })
        local opts = { a = 3, b = 'test' }

        stub_vars_buf_remote_path_get(path)
        stub(plugin.api, 'write_file_text', 'some error', nil)
        stub(vim.fn, 'getbufline', content_lines)
        stub(vim.api, 'nvim_buf_set_option')

        -- Fails as we return an error from writing text
        assert.has.errors(function()
            editor.write(vim.tbl_extend('keep', { buf = 123 }, opts))
        end)

        assert.stub(vim.api.nvim_buf_set_option).was.not_called()
    end)
end)
