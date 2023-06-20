local actions = require('distant.nav.actions')
local editor = require('distant.editor')
local Driver = require('spec.e2e.driver')
local stub = require('luassert.stub')

describe('distant.nav.actions.remove', function()
    --- @type spec.e2e.Driver, spec.e2e.RemoteDir, string
    local driver, root, sep

    before_each(function()
        driver = Driver:setup({
            label = 'distant.nav.actions.remove',

            -- Disable watching buffer content changes for our tests
            settings = {
                buffer = {
                    watch = {
                        enabled = false
                    }
                }
            },
        })

        -- TODO: This is really expensive, but plenary doesn't offer setup/teardown
        --       functions that we could use to limit this to the the entire
        --       describe block
        --
        --       Because we don't know when the last it(...) would finish, we cannot
        --       support manually creating a fixture and unloading it as it would
        --       get unloaded while other it blocks are still using it
        root = driver:new_dir_fixture({
            items = {
                'dir1/',
                'dir1/dir1-file1',
                'dir1/dir1-file2',

                'dir1/sub1/',
                'dir1/sub1/dir1-sub1-file1',

                'dir1/sub2/',

                'dir2/',
                'dir2/dir2-file1',
                'dir2/dir2-file2',

                'file1',
                'file2',
            }
        })

        sep = driver:detect_remote_path_separator()
    end)

    after_each(function()
        driver:teardown()
    end)

    it('should remove the file under cursor and refresh the current buffer', function()
        -- 1 is yes, 2 is force, 3 is no
        -- TODO: Is there a way to provide input to the prompt without stubbing it?
        stub(vim.fn, 'confirm', 1)

        local buf = driver:buffer(editor.open(root:path()))

        -- Ensure we are pointing at the right line
        assert(
            driver:window():move_cursor_to('file1'),
            'Failed to move cursor to line'
        )

        -- Perform remove action
        actions.remove()

        -- Should not have changed buffers
        assert.are.equal(buf:id(), vim.api.nvim_get_current_buf())

        -- Check that our current buffer reflects lack of file
        buf.assert.same({
            'dir1' .. sep,
            'dir2' .. sep,
            'file2',
        })

        -- Check that the file was removed
        assert.is.falsy(root:file('file1'):exists())
    end)

    it('should remove the directory under cursor and refresh the current buffer', function()
        -- 1 is yes, 2 is force, 3 is no
        -- TODO: Is there a way to provide input to the prompt without stubbing it?
        stub(vim.fn, 'confirm', 1)

        local buf = driver:buffer(editor.open(root:path() .. sep .. 'dir1'))

        -- Ensure we are pointing at the right line
        assert(
            driver:window():move_cursor_to('sub2'),
            'Failed to move cursor to line'
        )

        -- Perform remove action
        actions.remove()

        -- Should not have changed buffers
        assert.are.equal(buf:id(), vim.api.nvim_get_current_buf())

        -- Check that our current buffer reflects lack of directory
        buf.assert.same({
            'dir1-file1',
            'dir1-file2',
            'sub1' .. sep,
        })

        -- Check that the directory was removed
        assert.is.falsy(root:dir('dir1' .. sep .. 'sub2'):exists())
    end)

    it('should fail to remove a non-empty directory', function()
        -- 1 is yes, 2 is force, 3 is no
        -- TODO: Is there a way to provide input to the prompt without stubbing it?
        stub(vim.fn, 'confirm', 1)

        local buf = driver:buffer(editor.open(root:path()))

        -- Ensure we are pointing at the right line
        assert(
            driver:window():move_cursor_to('dir2'),
            'Failed to move cursor to line'
        )

        -- Perform remove action
        actions.remove()

        -- Should not have changed buffers
        assert.are.equal(buf:id(), vim.api.nvim_get_current_buf())

        -- Check that our current buffer still reflects all directories
        buf.assert.same({
            'dir1' .. sep,
            'dir2' .. sep,
            'file1',
            'file2',
        })

        -- Check that the directory still exists
        assert.is.truthy(root:dir('dir2'):exists())
    end)

    it('should support force-deleting a non-empty directory', function()
        -- 1 is yes, 2 is force, 3 is no
        -- TODO: Is there a way to provide input to the prompt without stubbing it?
        stub(vim.fn, 'confirm', 2)

        local buf = driver:buffer(editor.open(root:path()))

        -- Ensure we are pointing at the right line
        assert(
            driver:window():move_cursor_to('dir2'),
            'Failed to move cursor to line'
        )

        -- Perform remove action
        actions.remove({ force = true })

        -- Should not have changed buffers
        assert.are.equal(buf:id(), vim.api.nvim_get_current_buf())

        -- Check that our current buffer reflects lack of directory
        buf.assert.same({
            'dir1' .. sep,
            'file1',
            'file2',
        })

        -- Check that the directory no longer exists
        assert.is.falsy(root:dir('dir2'):exists())
    end)

    it('should not prompt and automatically confirm yes if no_prompt == true', function()
        local buf = driver:buffer(editor.open(root:path()))

        -- Ensure we are pointing at the right line
        assert(
            driver:window():move_cursor_to('file1'),
            'Failed to move cursor to line'
        )

        -- Perform remove action
        actions.remove({ no_prompt = true })

        -- Should not have changed buffers
        assert.are.equal(buf:id(), vim.api.nvim_get_current_buf())

        -- Check that our current buffer reflects lack of file
        buf.assert.same({
            'dir1' .. sep,
            'dir2' .. sep,
            'file2',
        })

        -- Check that the file was removed
        assert.is.falsy(root:file('file1'):exists())
    end)

    it('should do nothing if no specified at prompt', function()
        -- 1 is yes, 2 is force, 3 is no
        -- TODO: Is there a way to provide input to the prompt without stubbing it?
        stub(vim.fn, 'confirm', 3)

        local buf = driver:buffer(editor.open(root:path()))

        -- Ensure we are pointing at the right line
        assert(
            driver:window():move_cursor_to('file1'),
            'Failed to move cursor to line'
        )

        -- Perform remove action
        actions.remove()

        -- Should not have changed buffers
        assert.are.equal(buf:id(), vim.api.nvim_get_current_buf())

        -- Check that our current buffer still reflects full directory
        buf.assert.same({
            'dir1' .. sep,
            'dir2' .. sep,
            'file1',
            'file2',
        })

        -- Check that the file was not removed
        assert.is.truthy(root:file('file1'):exists())
    end)

    it('should do nothing if not in a remote buffer', function()
        local buf = driver:make_buffer('some contents', { modified = false })
        driver:window():set_buf(buf:id())

        -- Perform remove action
        actions.remove({ no_prompt = true })

        -- Should not have changed buffers
        assert.are.equal(buf:id(), vim.api.nvim_get_current_buf())

        -- Buffer contents should remain the same
        buf.assert.same('some contents')
    end)
end)
