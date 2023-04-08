local editor = require('distant.editor')
local fn = require('distant.fn')
local match = require('luassert.match')
local stub = require('luassert.stub')
local vars = require('distant-core.vars')

--- Creates a stubbed vars.buf(...) instance
--- that returns a table with only `remote_path`
--- that is also stubbed to return `value`
--- upon call to `get()`
---
--- Returns the stubbed `vars.buf(...).remote_path.get`
local function stub_vars_buf_remote_path_get(value)
    local remote_path = {
        get = function()
        end
    }
    stub(remote_path, 'get', value)

    local buf = { remote_path = remote_path }
    stub(vars, 'buf', buf)

    return remote_path.get
end

describe('editor.write', function()
    it('should do nothing if the buffer does not have a remote path', function()
        local remote_path_get = stub_vars_buf_remote_path_get(nil)
        stub(fn, 'write_file_text')

        editor.write(123)
        assert.stub(remote_path_get).was.called_with(123)
        assert.stub(fn.write_file_text).was.not_called()
    end)

    it('should write all lines of the buffer to the remote file', function()
        local path = 'some/path'
        local contents = 'some lines\nof text\nfor a file'
        local content_lines = vim.split(contents, '\n', true)
        local opts = { a = 3, b = 'test' }

        local remote_path_get = stub_vars_buf_remote_path_get(path)
        stub(fn, 'write_file_text', false, true)
        stub(vim.fn, 'getbufline', content_lines)
        stub(vim.api, 'nvim_buf_set_option')

        editor.write(vim.tbl_extend('keep', { buf = 123 }, opts))

        local _ = match._
        assert.stub(remote_path_get).was.called_with(123)
        assert.stub(vim.fn.getbufline).was.called_with(123, _, _)
        assert.stub(fn.write_file_text).was.called_with({
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
        local content_lines = vim.split(contents, '\n', true)
        local opts = { a = 3, b = 'test' }

        stub_vars_buf_remote_path_get(path)
        stub(fn, 'write_file_text', 'some error', nil)
        stub(vim.fn, 'getbufline', content_lines)
        stub(vim.api, 'nvim_buf_set_option')

        -- Fails as we return an error from writing text
        assert.has.errors(function()
            editor.write(vim.tbl_extend('keep', { buf = 123 }, opts))
        end)

        assert.stub(vim.api.nvim_buf_set_option).was.not_called()
    end)
end)
