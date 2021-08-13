local editor = require('distant.editor')
local fn = require('distant.fn')
local Driver = require('spec.e2e.driver')

describe('editor.open', function()
    local driver, fixture

    before_each(function()
        driver = Driver:setup()
        fixture = driver:new_fixture({
            ext = 'txt',
            lines = {
                'This is a file used for tests',
                'with multiple lines of text.',
            },
        })
    end)

    after_each(function()
        -- Will remove all fixtures
        driver:teardown()
    end)

    it('should open a file and set appropriate configuration', function()
        local test_path = fixture.path()
        local buf = driver.buffer(editor.open(test_path))

        -- Read the contents of the buffer that should have been populated
        buf.assert.same({
            'This is a file used for tests',
            'with multiple lines of text.',
        })

        -- Get the absolute path to the file we are editing
        local err, metadata = fn.metadata(test_path, {canonicalize = true})
        assert(not err, err)

        -- Verify we set a remote path variable to the absolute path
        local remote_path = buf.get_var('distant_remote_path')
        assert.are.equal(metadata.canonicalized_path, remote_path)

        -- Verify we set file-specific buffer properties
        assert.are.equal(remote_path, buf.name())
        assert.are.equal('text', buf.filetype())
        assert.are.equal('acwrite', buf.buftype())

        -- Verify we switched our window to the current buffer
        assert.are.equal(buf.id(), vim.api.nvim_win_get_buf(0))
    end)

    it('should configure file buffers to send contents to remote server on write', function()
        local test_path = fixture.path()
        local buf = driver.buffer(editor.open(test_path))

        -- Change the buffer and write it back to the remote destination
        buf.set_lines({'line 1', 'line 2'})
        vim.cmd([[write]])

        -- Verify that the remote file did change
        fixture.assert.same({'line 1', 'line 2'})
    end)

    it('should configure file buffers to reload contents from remote server on edit', function()
        local test_path = fixture.path()
        local buf = driver.buffer(editor.open(test_path))

        -- Change our buffer to something new
        buf.set_lines({'line 1', 'line 2'})

        -- Verify that buffer has been updated with new contents
        buf.assert.same({'line 1', 'line 2'})

        -- Edit the buffer to reload (discard current contents)
        -- NOTE: This requires a blocking read
        vim.cmd([[edit!]])

        -- Verify that buffer has been updated with current remote contents
        buf.assert.same(fixture.lines())
    end)
end)
