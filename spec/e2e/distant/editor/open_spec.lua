local editor = require('distant.editor')
local fn = require('distant.fn')
local Driver = require('spec.e2e.driver')

describe('distant.editor.open', function()
    --- @type spec.e2e.Driver, spec.e2e.RemoteFile, spec.e2e.RemoteDir
    local driver, file, dir

    before_each(function()
        driver = Driver:setup({ label = 'editor.open' })
        file = driver:new_file_fixture({
            ext = 'txt',
            lines = {
                'This is a file used for tests',
                'with multiple lines of text.',
            },
        })
        dir = driver:new_dir_fixture()
    end)

    after_each(function()
        -- Will remove all fixtures
        driver:teardown()
    end)

    it('should open a directory and set appropriate configuration', function()
        -- Set up some items within the directory
        dir:dir('dir1'):make()
        dir:dir('dir2'):make()
        dir:file('file1'):touch()
        dir:file('file2'):touch()
        dir:file('file3'):touch()

        -- Load the directory into a buffer
        local test_path = dir:path()
        local buf = driver:buffer(editor.open(test_path))

        -- Verify the buffer contains the items
        buf.assert.same({
            'dir1',
            'dir2',
            'file1',
            'file2',
            'file3',
        })

        -- Get the absolute path to the file we are editing
        local err, metadata = fn.metadata({ path = test_path, canonicalize = true })
        assert(not err, err)
        assert(metadata)

        -- Verify we set a remote path variable to the absolute path
        local remote_path = buf:remote_path()
        assert.are.equal(metadata.canonicalized_path, remote_path)
        assert.are.equal('dir', buf:remote_type())

        -- Verify we set dir-specific buffer properties
        assert.are.equal('distant://' .. remote_path, buf:name())
        assert.are.equal('distant-dir', buf:filetype())
        assert.are.equal('nofile', buf:buftype())
        assert.is.falsy(buf:modifiable())

        -- Verify we switched our window to the current buffer
        assert.is.truthy(buf:is_focused())
    end)

    it('should open a file and set appropriate configuration', function()
        local test_path = file:path()
        local buf = driver:buffer(editor.open(test_path))

        -- Read the contents of the buffer that should have been populated
        buf.assert.same({
            'This is a file used for tests',
            'with multiple lines of text.',
        })

        -- Get the absolute path to the file we are editing
        local err, metadata = fn.metadata({ path = test_path, canonicalize = true })
        assert(not err, err)
        assert(metadata)

        -- Verify we set a remote path variable to the absolute path
        local remote_path = buf:remote_path()
        assert.are.equal(metadata.canonicalized_path, remote_path)
        assert.are.equal('file', buf:remote_type())

        -- Verify we set file-specific buffer properties
        assert.are.equal('distant://' .. remote_path, buf:name())
        assert.are.equal('text', buf:filetype())
        assert.are.equal('acwrite', buf:buftype())

        -- Verify we switched our window to the current buffer
        assert.is.truthy(buf:is_focused())
    end)

    it('should configure file buffers to send contents to remote server on write', function()
        local test_path = file:path()
        local buf = driver:buffer(editor.open(test_path))

        -- Change the buffer and write it back to the remote destination
        buf:set_lines({ 'line 1', 'line 2' })

        -- NOTE: To have write work, we require an autocmd for BufReadCmd, which only
        --       appears if we have called the setup function; so, if you get an error
        --       about no autocmd associated, it means we've not called setup for
        --       some reason!
        vim.cmd([[write]])

        -- Verify that the remote file did change
        file.assert.same({ 'line 1', 'line 2' })
    end)

    it('should configure file buffers to reload contents from remote server on edit', function()
        local test_path = file:path()
        local buf = driver:buffer(editor.open(test_path))

        -- Change our buffer to something new
        buf:set_lines({ 'line 1', 'line 2' })

        -- Verify that buffer has been updated with new contents
        buf.assert.same({ 'line 1', 'line 2' })

        -- Edit the buffer to reload (discard current contents)
        -- NOTE: This requires a blocking read
        vim.cmd([[edit!]])

        -- Verify that buffer has been updated with current remote contents
        buf.assert.same(assert(file:lines()))
    end)

    it('should support symlinks that are files', function()
        local symlink = driver:new_symlink_fixture({ source = file:path() })

        -- Load the file (symlink) into a buffer
        local test_path = symlink:path()
        local buf = driver:buffer(editor.open(test_path))

        -- Read the contents of the buffer that should have been populated
        buf.assert.same({
            'This is a file used for tests',
            'with multiple lines of text.',
        })

        -- Get the absolute path to the file we are editing
        local err, metadata = fn.metadata({ path = test_path, canonicalize = true })
        assert(not err, err)
        assert(metadata)

        -- Verify we set a remote path variable to the absolute path
        local remote_path = buf:remote_path()
        assert.are.equal(metadata.canonicalized_path, remote_path)
        assert.are.equal('file', buf:remote_type())

        -- Verify we set file-specific buffer properties
        assert.are.equal('distant://' .. remote_path, buf:name())
        assert.are.equal('text', buf:filetype())
        assert.are.equal('acwrite', buf:buftype())

        -- Verify we switched our window to the current buffer
        assert.is.truthy(buf:is_focused())
    end)

    it('should support symlinks that are directories', function()
        local symlink = driver:new_symlink_fixture({ source = dir:path() })

        -- Set up some items within the directory
        dir:dir('dir1'):make()
        dir:dir('dir2'):make()
        dir:file('file1'):touch()
        dir:file('file2'):touch()
        dir:file('file3'):touch()

        -- Load the directory (symlink) into a buffer
        local test_path = symlink:path()
        local buf = driver:buffer(editor.open(test_path))

        -- Verify the buffer contains the items
        buf.assert.same({
            'dir1',
            'dir2',
            'file1',
            'file2',
            'file3',
        })

        -- Get the absolute path to the file we are editing
        local err, metadata = fn.metadata({ path = test_path, canonicalize = true })
        assert(not err, err)
        assert(metadata)

        -- Verify we set a remote path variable to the absolute path
        local remote_path = buf:remote_path()
        assert.are.equal(metadata.canonicalized_path, remote_path)
        assert.are.equal('dir', buf:remote_type())

        -- Verify we set dir-specific buffer properties
        assert.are.equal('distant://' .. remote_path, buf:name())
        assert.are.equal('distant-dir', buf:filetype())
        assert.are.equal('nofile', buf:buftype())
        assert.is.falsy(buf:modifiable())

        -- Verify we switched our window to the current buffer
        assert.is.truthy(buf:is_focused())
    end)
end)
