local actions = require('distant.nav.actions')
local editor = require('distant.editor')
local Driver = require('spec.e2e.driver')

describe('distant.nav.actions.edit', function()
    --- @type spec.e2e.Driver, spec.e2e.RemoteDir, string
    local driver, root, sep

    before_each(function()
        driver = Driver:setup({
            label = 'distant.nav.actions.edit',

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

    it('should open the file under the cursor', function()
        local buf = driver:buffer(editor.open(root:path()))

        -- Ensure we are pointing at the right line
        assert(
            driver:window():move_cursor_to('file1'),
            'Failed to move cursor to line'
        )

        -- Perform edit action
        actions.edit()

        -- Should have changed buffers
        assert.are.not_equal(buf:id(), vim.api.nvim_get_current_buf())

        -- Check that our current buffer is pointing to the remote file
        assert.are.equal(root:canonicalized_path() .. sep .. 'file1', driver:buffer():remote_path())
        assert.are.equal('file', driver:buffer():remote_type())
    end)

    it('should open the directory under the cursor', function()
        local buf = driver:buffer(editor.open(root:path()))

        -- Ensure we are pointing at the right line
        assert(
            driver:window():move_cursor_to('dir1'),
            'Failed to move cursor to line'
        )

        -- Perform edit action
        actions.edit()

        -- Should have changed buffers
        assert.are.not_equal(buf:id(), vim.api.nvim_get_current_buf())

        -- Check that our current buffer is pointing to the remote directory
        assert.are.equal(root:canonicalized_path() .. sep .. 'dir1', driver:buffer():remote_path())
        assert.are.equal('dir', driver:buffer():remote_type())
    end)

    it('should do nothing if not in a remote buffer', function()
        local buf = driver:make_buffer('not_a_remote_file', { modified = false })
        driver:window():set_buf(buf:id())

        -- Ensure we are pointing at the right line
        assert(
            driver:window():move_cursor_to('not_a_remote_file'),
            'Failed to move cursor to line'
        )

        -- Perform edit action
        actions.edit()

        -- Should not have changed buffers
        assert.are.equal(buf:id(), vim.api.nvim_get_current_buf())

        -- Buffer contents should remain the same
        buf.assert.same('not_a_remote_file')
    end)
end)
