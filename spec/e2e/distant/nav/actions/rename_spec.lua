local actions = require('distant.nav.actions')
local editor = require('distant.editor')
local Driver = require('spec.e2e.driver')
local stub = require('luassert.stub')

describe('distant.nav.actions.rename', function()
    --- @type spec.e2e.Driver, spec.e2e.RemoteDir, string
    local driver, root, sep

    before_each(function()
        driver = Driver:setup({
            label = 'distant.nav.actions.rename',

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

    it('should rename the file under the cursor and refresh the current buffer', function()
        -- TODO: Is there a way to provide input to the prompt without stubbing it?
        stub(vim.fn, 'input', root:path() .. sep .. 'new_file')

        local buf = driver:buffer(editor.open(root:path()))

        -- Make sure our test file has content
        root:file('file1'):write('this is file 1')

        -- Ensure we are pointing at the right line
        assert(
            driver:window():move_cursor_to('file1'),
            'Failed to move cursor to line'
        )

        -- Perform rename action
        actions.rename()

        -- Should not have changed buffers
        assert.are.equal(buf:id(), vim.api.nvim_get_current_buf())

        -- Check that our current buffer reflects the same contents
        buf.assert.same({
            'dir1' .. sep,
            'dir2' .. sep,
            'file2',
            'new_file',
        })

        -- Check that our new file is just the renamed file
        root:file('new_file').assert.same('this is file 1')
    end)

    it('should rename the directory under the cursor and refresh the current buffer', function()
        -- TODO: Is there a way to provide input to the prompt without stubbing it?
        stub(vim.fn, 'input', root:path() .. sep .. 'new_dir')

        local buf = driver:buffer(editor.open(root:path()))

        -- Ensure we are pointing at the right line
        assert(
            driver:window():move_cursor_to('dir1'),
            'Failed to move cursor to line'
        )

        -- Perform rename action
        actions.rename()

        -- Should not have changed buffers
        assert.are.equal(buf:id(), vim.api.nvim_get_current_buf())

        -- Check that our current buffer reflects the same contents
        buf.assert.same({
            'dir2' .. sep,
            'file1',
            'file2',
            'new_dir' .. sep,
        })

        -- Check that our new dir is just the renamed dir
        assert.are.same({
            'dir1-file1',
            'dir1-file2',
            'sub1',
            'sub2',
        }, root:dir('new_dir'):items())
    end)

    it('should do nothing if no new name provided', function()
        -- TODO: Is there a way to provide input to the prompt without stubbing it?
        stub(vim.fn, 'input', '')

        local buf = driver:buffer(editor.open(root:path()))

        -- Ensure we are pointing at the right line
        assert(
            driver:window():move_cursor_to('file1'),
            'Failed to move cursor to line'
        )

        -- Perform rename action
        actions.rename()

        -- Should not have changed buffers
        assert.are.equal(buf:id(), vim.api.nvim_get_current_buf())

        -- Check that our current buffer reflects the same contents
        buf.assert.same({
            'dir1' .. sep,
            'dir2' .. sep,
            'file1',
            'file2',
        })
    end)

    it('should do nothing if not in a remote buffer', function()
        local buf = driver:make_buffer('some contents', { modified = false })
        driver:window():set_buf(buf:id())

        -- Perform rename action
        actions.rename({ path = 'new.txt' })

        -- Should not have changed buffers
        assert.are.equal(buf:id(), vim.api.nvim_get_current_buf())

        -- Buffer contents should remain the same
        buf.assert.same('some contents')
    end)
end)
