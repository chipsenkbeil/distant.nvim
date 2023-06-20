local actions = require('distant.nav.actions')
local editor = require('distant.editor')
local Driver = require('spec.e2e.driver')
local stub = require('luassert.stub')

describe('distant.nav.actions.newfile', function()
    --- @type spec.e2e.Driver, spec.e2e.RemoteDir, string
    local driver, root, sep

    before_each(function()
        driver = Driver:setup({
            label = 'distant.nav.actions.newfile',

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

    it('should open a new file using the given name', function()
        -- TODO: Is there a way to provide input to the prompt without stubbing it?
        stub(vim.fn, 'input', 'new_file')

        local buf = driver:buffer(editor.open(root:path()))

        -- Perform rename action
        actions.newfile()

        -- Should have changed buffers to the new file
        assert.are.not_equal(buf:id(), vim.api.nvim_get_current_buf())

        -- Check that our current buffer is pointing to the new remote file
        assert.are.equal(root:canonicalized_path() .. sep .. 'new_file', driver:buffer():remote_path())
        assert.are.equal('file', driver:buffer():remote_type())

        -- Check that our new file does not exist yet
        assert.is.falsy(root:file('new_file'):exists())
    end)

    it('should do nothing if no new name provided', function()
        -- TODO: Is there a way to provide input to the prompt without stubbing it?
        stub(vim.fn, 'input', '')

        local buf = driver:buffer(editor.open(root:path()))

        -- Perform rename action
        actions.newfile()

        -- Should not have changed buffers
        assert.are.equal(buf:id(), vim.api.nvim_get_current_buf())

        -- Check that our current buffer reflects the new file
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

        -- Perform newfile action
        actions.newfile({ path = 'new.txt' })

        -- Should not have changed buffers
        assert.are.equal(buf:id(), vim.api.nvim_get_current_buf())

        -- Buffer contents should remain the same
        buf.assert.same('some contents')
    end)
end)
