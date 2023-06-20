local editor = require('distant.editor')
local plugin = require('distant')
local Driver = require('spec.e2e.driver')

describe('distant.editor.open', function()
    --- @type spec.e2e.Driver, spec.e2e.RemoteFile, spec.e2e.RemoteDir, string
    local driver, file, dir, sep

    before_each(function()
        driver = Driver:setup({
            label = 'distant.editor.open',

            -- Disable watching buffer content changes for our tests
            settings = {
                buffer = {
                    watch = {
                        enabled = false
                    }
                }
            },
        })
        file = driver:new_file_fixture({
            ext = 'txt',
            lines = {
                'This is a file used for tests',
                'with multiple lines of text.',
            },
        })
        dir = driver:new_dir_fixture()
        sep = driver:detect_remote_path_separator()
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
        local buffer = driver:buffer(editor.open(test_path))

        -- Verify the buffer contains the items
        buffer.assert.same({
            'dir1' .. sep,
            'dir2' .. sep,
            'file1',
            'file2',
            'file3',
        })

        -- Get the absolute path to the file we are editing
        local err, metadata = plugin.api.metadata({ path = test_path, canonicalize = true })
        assert(not err, tostring(err))
        assert(metadata)

        -- Verify we set a remote path variable to the absolute path
        local remote_path = buffer:remote_path()
        assert.are.equal(metadata.canonicalized_path, remote_path)
        assert.are.equal('dir', buffer:remote_type())

        -- Verify we set dir-specific buffer properties
        if plugin.buf.name.default_format() == 'modern' then
            assert.are.equal(
                'distant+' .. driver:client_id() .. '://' .. remote_path,
                buffer:name()
            )
        else
            assert.are.equal(
                'distant://' .. driver:client_id() .. '://' .. remote_path,
                buffer:name()
            )
        end
        assert.are.equal('distant-dir', buffer:filetype())
        assert.are.equal('nofile', buffer:buftype())
        assert.is.falsy(buffer:modifiable())

        -- Verify we switched our window to the current buffer
        assert.is.truthy(buffer:is_focused())
    end)

    it('should open a file and set appropriate configuration', function()
        local test_path = file:path()
        local buffer = driver:buffer(editor.open(test_path))

        -- Read the contents of the buffer that should have been populated
        buffer.assert.same({
            'This is a file used for tests',
            'with multiple lines of text.',
        })

        -- Get the absolute path to the file we are editing
        local err, metadata = plugin.api.metadata({ path = test_path, canonicalize = true })
        assert(not err, tostring(err))
        assert(metadata)

        -- Verify we set a remote path variable to the absolute path
        local remote_path = buffer:remote_path()
        assert.are.equal(metadata.canonicalized_path, remote_path)
        assert.are.equal('file', buffer:remote_type())

        -- Verify we set file-specific buffer properties
        if plugin.buf.name.default_format() == 'modern' then
            assert.are.equal(
                'distant+' .. driver:client_id() .. '://' .. remote_path,
                buffer:name()
            )
        else
            assert.are.equal(
                'distant://' .. driver:client_id() .. '://' .. remote_path,
                buffer:name()
            )
        end
        assert.are.equal('text', buffer:filetype())
        assert.are.equal('acwrite', buffer:buftype())

        -- Verify the mtime field was set to the file's mtime
        assert.are.equal(metadata.modified, buffer:remote_mtime())

        -- Verify we switched our window to the current buffer
        assert.is.truthy(buffer:is_focused())
    end)

    it('should configure file buffers to send contents to remote server on write', function()
        local test_path = file:path()
        local buffer = driver:buffer(editor.open(test_path))

        -- Change the buffer and write it back to the remote destination
        buffer:set_lines({ 'line 1', 'line 2' })

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
        local buffer = driver:buffer(editor.open(test_path))

        -- Change our buffer to something new
        buffer:set_lines({ 'line 1', 'line 2' })

        -- Verify that buffer has been updated with new contents
        buffer.assert.same({ 'line 1', 'line 2' })

        -- Edit the buffer to reload (discard current contents)
        -- NOTE: This requires a blocking read
        vim.cmd([[edit!]])

        -- Verify that buffer has been updated with current remote contents
        buffer.assert.same(assert(file:lines()))
    end)

    it('should support symlinks that are files', function()
        local symlink = driver:new_symlink_fixture({ source = file:path() })

        -- Load the file (symlink) into a buffer
        local test_path = symlink:path()
        local buffer = driver:buffer(editor.open(test_path))

        -- Read the contents of the buffer that should have been populated
        buffer.assert.same({
            'This is a file used for tests',
            'with multiple lines of text.',
        })

        -- Get the absolute path to the file we are editing
        local err, metadata = plugin.api.metadata({ path = test_path, canonicalize = true })
        assert(not err, tostring(err))
        assert(metadata)

        -- Verify we set a remote path variable to the absolute path
        local remote_path = buffer:remote_path()
        assert.are.equal(metadata.canonicalized_path, remote_path)
        assert.are.equal('file', buffer:remote_type())

        -- Verify we set file-specific buffer properties
        if plugin.buf.name.default_format() == 'modern' then
            assert.are.equal(
                'distant+' .. driver:client_id() .. '://' .. remote_path,
                buffer:name()
            )
        else
            assert.are.equal(
                'distant://' .. driver:client_id() .. '://' .. remote_path,
                buffer:name()
            )
        end
        assert.are.equal('text', buffer:filetype())
        assert.are.equal('acwrite', buffer:buftype())

        -- Verify we switched our window to the current buffer
        assert.is.truthy(buffer:is_focused())
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
        local buffer = driver:buffer(editor.open(test_path))

        -- Verify the buffer contains the items
        buffer.assert.same({
            'dir1' .. sep,
            'dir2' .. sep,
            'file1',
            'file2',
            'file3',
        })

        -- Get the absolute path to the file we are editing
        local err, metadata = plugin.api.metadata({ path = test_path, canonicalize = true })
        assert(not err, tostring(err))
        assert(metadata)

        -- Verify we set a remote path variable to the absolute path
        local remote_path = buffer:remote_path()
        assert.are.equal(metadata.canonicalized_path, remote_path)
        assert.are.equal('dir', buffer:remote_type())

        -- Verify we set dir-specific buffer properties
        if plugin.buf.name.default_format() == 'modern' then
            assert.are.equal(
                'distant+' .. driver:client_id() .. '://' .. remote_path,
                buffer:name()
            )
        else
            assert.are.equal(
                'distant://' .. driver:client_id() .. '://' .. remote_path,
                buffer:name()
            )
        end
        assert.are.equal('distant-dir', buffer:filetype())
        assert.are.equal('nofile', buffer:buftype())
        assert.is.falsy(buffer:modifiable())

        -- Verify we switched our window to the current buffer
        assert.is.truthy(buffer:is_focused())
    end)
end)
