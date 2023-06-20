local actions = require('distant.nav.actions')
local editor = require('distant.editor')
local Driver = require('spec.e2e.driver')
local stub = require('luassert.stub')

describe('distant.nav.actions.mkdir', function()
    --- @type spec.e2e.Driver, spec.e2e.RemoteDir, string
    local driver, root, sep

    before_each(function()
        driver = Driver:setup({
            label = 'distant.nav.actions.mkdir',

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

    it('should create the directory and refresh the current buffer', function()
        -- TODO: Is there a way to provide input to the prompt without stubbing it?
        stub(vim.fn, 'input', 'new_dir')

        local buf = driver:buffer(editor.open(root:path()))

        -- Perform rename action
        actions.mkdir()

        -- Should not have changed buffers
        assert.are.equal(buf:id(), vim.api.nvim_get_current_buf())

        -- Check that our current buffer reflects the new directory
        buf.assert.same({
            'dir1' .. sep,
            'dir2' .. sep,
            'file1',
            'file2',
            'new_dir' .. sep,
        })

        -- Check that our new directory exists
        assert.is.truthy(root:dir('new_dir'):exists())
    end)

    it('should do nothing if no directory name provided', function()
        -- TODO: Is there a way to provide input to the prompt without stubbing it?
        stub(vim.fn, 'input', '')

        local buf = driver:buffer(editor.open(root:path()))

        -- Perform rename action
        actions.mkdir()

        -- Should not have changed buffers
        assert.are.equal(buf:id(), vim.api.nvim_get_current_buf())

        -- Check that our current buffer reflects nothing changed
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

        -- Perform mkdir action
        actions.mkdir({ path = 'new.dir' })

        -- Should not have changed buffers
        assert.are.equal(buf:id(), vim.api.nvim_get_current_buf())

        -- Buffer contents should remain the same
        buf.assert.same('some contents')
    end)
end)
