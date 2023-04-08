local actions = require('distant.nav.actions')
local editor = require('distant.editor')
local Driver = require('spec.e2e.driver')
local stub = require('luassert.stub')

describe('actions', function()
    local driver, root

    before_each(function()
        driver = Driver:setup({ label = 'nav.actions' })

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
    end)

    after_each(function()
        driver:teardown()
    end)

    describe('edit', function()
        it('should open the file under the cursor', function()
            local buf = driver.buffer(editor.open(root.path()))

            -- Ensure we are pointing at the right line
            assert(
                driver.window().move_cursor_to('file1'),
                'Failed to move cursor to line'
            )

            -- Perform edit action
            actions.edit()

            -- Should have changed buffers
            assert.are.not_equal(buf.id(), vim.api.nvim_get_current_buf())

            -- Check that our current buffer is pointing to the remote file
            assert.are.equal(root.path() .. '/' .. 'file1', driver.buffer().remote_path())
            assert.are.equal('file', driver.buffer().remote_type())
        end)

        it('should open the directory under the cursor', function()
            local buf = driver.buffer(editor.open(root.path()))

            -- Ensure we are pointing at the right line
            assert(
                driver.window().move_cursor_to('dir1'),
                'Failed to move cursor to line'
            )

            -- Perform edit action
            actions.edit()

            -- Should have changed buffers
            assert.are.not_equal(buf.id(), vim.api.nvim_get_current_buf())

            -- Check that our current buffer is pointing to the remote directory
            assert.are.equal(root.path() .. '/' .. 'dir1', driver.buffer().remote_path())
            assert.are.equal('dir', driver.buffer().remote_type())
        end)

        it('should do nothing if not in a remote buffer', function()
            local buf = driver.make_buffer('not_a_remote_file', { modified = false })
            driver.window().set_buf(buf.id())

            -- Ensure we are pointing at the right line
            assert(
                driver.window().move_cursor_to('not_a_remote_file'),
                'Failed to move cursor to line'
            )

            -- Perform edit action
            actions.edit()

            -- Should not have changed buffers
            assert.are.equal(buf.id(), vim.api.nvim_get_current_buf())

            -- Buffer contents should remain the same
            buf.assert.same('not_a_remote_file')
        end)
    end)

    describe('up', function()
        it('should open the parent directory of an open remote directory', function()
            local buf = driver.buffer(editor.open(root.path() .. '/dir1/sub1'))

            -- Perform up action
            actions.up()

            -- Should have changed buffers
            assert.are.not_equal(buf.id(), vim.api.nvim_get_current_buf())

            -- Check that our current buffer is pointing to the remote file
            assert.are.equal(root.path() .. '/' .. 'dir1', driver.buffer().remote_path())
            assert.are.equal('dir', driver.buffer().remote_type())
            assert.are.equal('distant-dir', driver.buffer().filetype())
        end)

        it('should open the parent directory of an open remote file', function()
            local buf = driver.buffer(editor.open(root.path() .. '/dir1/dir1-file1'))

            -- Perform up action
            actions.up()

            -- Should have changed buffers
            assert.are.not_equal(buf.id(), vim.api.nvim_get_current_buf())

            -- Check that our current buffer is pointing to the remote directory
            assert.are.equal(root.path() .. '/' .. 'dir1', driver.buffer().remote_path())
            assert.are.equal('dir', driver.buffer().remote_type())
            assert.are.equal('distant-dir', driver.buffer().filetype())
        end)

        it('should do nothing if not in a remote buffer', function()
            local buf = driver.make_buffer('some contents', { modified = false })
            driver.window().set_buf(buf.id())

            -- Perform up action
            actions.up()

            -- Should not have changed buffers
            assert.are.equal(buf.id(), vim.api.nvim_get_current_buf())

            -- Buffer contents should remain the same
            buf.assert.same('some contents')
        end)
    end)

    describe('newfile', function()
        it('should open a new file using the given name', function()
            -- TODO: Is there a way to provide input to the prompt without stubbing it?
            stub(vim.fn, 'input', 'new_file')

            local buf = driver.buffer(editor.open(root.path()))

            -- Perform rename action
            actions.newfile()

            -- Should have changed buffers to the new file
            assert.are.not_equal(buf.id(), vim.api.nvim_get_current_buf())

            -- Check that our current buffer is pointing to the new remote file
            assert.are.equal(root.path() .. '/' .. 'new_file', driver.buffer().remote_path())
            assert.are.equal('file', driver.buffer().remote_type())

            -- Check that our new file does not exist yet
            assert.is.falsy(root.file('new_file').exists())
        end)

        it('should do nothing if no new name provided', function()
            -- TODO: Is there a way to provide input to the prompt without stubbing it?
            stub(vim.fn, 'input', '')

            local buf = driver.buffer(editor.open(root.path()))

            -- Perform rename action
            actions.newfile()

            -- Should not have changed buffers
            assert.are.equal(buf.id(), vim.api.nvim_get_current_buf())

            -- Check that our current buffer reflects the new file
            buf.assert.same({
                'dir1',
                'dir2',
                'file1',
                'file2',
            })
        end)

        it('should do nothing if not in a remote buffer', function()
            local buf = driver.make_buffer('some contents', { modified = false })
            driver.window().set_buf(buf.id())

            -- Perform newfile action
            actions.newfile({ path = 'new.txt' })

            -- Should not have changed buffers
            assert.are.equal(buf.id(), vim.api.nvim_get_current_buf())

            -- Buffer contents should remain the same
            buf.assert.same('some contents')
        end)
    end)

    describe('mkdir', function()
        it('should create the directory and refresh the current buffer', function()
            -- TODO: Is there a way to provide input to the prompt without stubbing it?
            stub(vim.fn, 'input', 'new_dir')

            local buf = driver.buffer(editor.open(root.path()))

            -- Perform rename action
            actions.mkdir()

            -- Should not have changed buffers
            assert.are.equal(buf.id(), vim.api.nvim_get_current_buf())

            -- Check that our current buffer reflects the new directory
            buf.assert.same({
                'dir1',
                'dir2',
                'file1',
                'file2',
                'new_dir',
            })

            -- Check that our new directory exists
            assert.is.truthy(root.dir('new_dir').exists())
        end)

        it('should do nothing if no directory name provided', function()
            -- TODO: Is there a way to provide input to the prompt without stubbing it?
            stub(vim.fn, 'input', '')

            local buf = driver.buffer(editor.open(root.path()))

            -- Perform rename action
            actions.mkdir()

            -- Should not have changed buffers
            assert.are.equal(buf.id(), vim.api.nvim_get_current_buf())

            -- Check that our current buffer reflects nothing changed
            buf.assert.same({
                'dir1',
                'dir2',
                'file1',
                'file2',
            })
        end)

        it('should do nothing if not in a remote buffer', function()
            local buf = driver.make_buffer('some contents', { modified = false })
            driver.window().set_buf(buf.id())

            -- Perform mkdir action
            actions.mkdir({ path = 'new.dir' })

            -- Should not have changed buffers
            assert.are.equal(buf.id(), vim.api.nvim_get_current_buf())

            -- Buffer contents should remain the same
            buf.assert.same('some contents')
        end)
    end)

    describe('rename', function()
        it('should rename the file under the cursor and refresh the current buffer', function()
            -- TODO: Is there a way to provide input to the prompt without stubbing it?
            stub(vim.fn, 'input', root.path() .. '/new_file')

            local buf = driver.buffer(editor.open(root.path()))

            -- Make sure our test file has content
            root.file('file1').write('this is file 1')

            -- Ensure we are pointing at the right line
            assert(
                driver.window().move_cursor_to('file1'),
                'Failed to move cursor to line'
            )

            -- Perform rename action
            actions.rename()

            -- Should not have changed buffers
            assert.are.equal(buf.id(), vim.api.nvim_get_current_buf())

            -- Check that our current buffer reflects the same contents
            buf.assert.same({
                'dir1',
                'dir2',
                'file2',
                'new_file',
            })

            -- Check that our new file is just the renamed file
            root.file('new_file').assert.same('this is file 1')
        end)

        it('should rename the directory under the cursor and refresh the current buffer', function()
            -- TODO: Is there a way to provide input to the prompt without stubbing it?
            stub(vim.fn, 'input', root.path() .. '/new_dir')

            local buf = driver.buffer(editor.open(root.path()))

            -- Ensure we are pointing at the right line
            assert(
                driver.window().move_cursor_to('dir1'),
                'Failed to move cursor to line'
            )

            -- Perform rename action
            actions.rename()

            -- Should not have changed buffers
            assert.are.equal(buf.id(), vim.api.nvim_get_current_buf())

            -- Check that our current buffer reflects the same contents
            buf.assert.same({
                'dir2',
                'file1',
                'file2',
                'new_dir',
            })

            -- Check that our new dir is just the renamed dir
            assert.are.same({
                'dir1-file1',
                'dir1-file2',
                'sub1',
                'sub2',
            }, root.dir('new_dir').items())
        end)

        it('should do nothing if no new name provided', function()
            -- TODO: Is there a way to provide input to the prompt without stubbing it?
            stub(vim.fn, 'input', '')

            local buf = driver.buffer(editor.open(root.path()))

            -- Ensure we are pointing at the right line
            assert(
                driver.window().move_cursor_to('file1'),
                'Failed to move cursor to line'
            )

            -- Perform rename action
            actions.rename()

            -- Should not have changed buffers
            assert.are.equal(buf.id(), vim.api.nvim_get_current_buf())

            -- Check that our current buffer reflects the same contents
            buf.assert.same({
                'dir1',
                'dir2',
                'file1',
                'file2',
            })
        end)

        it('should do nothing if not in a remote buffer', function()
            local buf = driver.make_buffer('some contents', { modified = false })
            driver.window().set_buf(buf.id())

            -- Perform rename action
            actions.rename({ path = 'new.txt' })

            -- Should not have changed buffers
            assert.are.equal(buf.id(), vim.api.nvim_get_current_buf())

            -- Buffer contents should remain the same
            buf.assert.same('some contents')
        end)
    end)

    describe('remove', function()
        it('should remove the file under cursor and refresh the current buffer', function()
            -- TODO: Is there a way to provide input to the prompt without stubbing it?
            stub(vim.fn, 'confirm', 1)

            local buf = driver.buffer(editor.open(root.path()))

            -- Ensure we are pointing at the right line
            assert(
                driver.window().move_cursor_to('file1'),
                'Failed to move cursor to line'
            )

            -- Perform remove action
            actions.remove()

            -- Should not have changed buffers
            assert.are.equal(buf.id(), vim.api.nvim_get_current_buf())

            -- Check that our current buffer reflects lack of file
            buf.assert.same({
                'dir1',
                'dir2',
                'file2',
            })

            -- Check that the file was removed
            assert.is.falsy(root.file('file1').exists())
        end)

        it('should remove the directory under cursor and refresh the current buffer', function()
            -- TODO: Is there a way to provide input to the prompt without stubbing it?
            stub(vim.fn, 'confirm', 1)

            local buf = driver.buffer(editor.open(root.path() .. '/dir1'))

            -- Ensure we are pointing at the right line
            assert(
                driver.window().move_cursor_to('sub2'),
                'Failed to move cursor to line'
            )

            -- Perform remove action
            actions.remove()

            -- Should not have changed buffers
            assert.are.equal(buf.id(), vim.api.nvim_get_current_buf())

            -- Check that our current buffer reflects lack of directory
            buf.assert.same({
                'dir1-file1',
                'dir1-file2',
                'sub1',
            })

            -- Check that the directory was removed
            assert.is.falsy(root.dir('dir1/sub2').exists())
        end)

        it('should fail to remove a non-empty directory', function()
            -- TODO: Is there a way to provide input to the prompt without stubbing it?
            stub(vim.fn, 'confirm', 1)

            local buf = driver.buffer(editor.open(root.path()))

            -- Ensure we are pointing at the right line
            assert(
                driver.window().move_cursor_to('dir2'),
                'Failed to move cursor to line'
            )

            -- Perform remove action
            actions.remove()

            -- Should not have changed buffers
            assert.are.equal(buf.id(), vim.api.nvim_get_current_buf())

            -- Check that our current buffer still reflects all directories
            buf.assert.same({
                'dir1',
                'dir2',
                'file1',
                'file2',
            })

            -- Check that the directory still exists
            assert.is.truthy(root.dir('dir2').exists())
        end)

        it('should support force-deleting a non-empty directory', function()
            -- TODO: Is there a way to provide input to the prompt without stubbing it?
            stub(vim.fn, 'confirm', 1)

            local buf = driver.buffer(editor.open(root.path()))

            -- Ensure we are pointing at the right line
            assert(
                driver.window().move_cursor_to('dir2'),
                'Failed to move cursor to line'
            )

            -- Perform remove action
            actions.remove({ force = true })

            -- Should not have changed buffers
            assert.are.equal(buf.id(), vim.api.nvim_get_current_buf())

            -- Check that our current buffer reflects lack of directory
            buf.assert.same({
                'dir1',
                'file1',
                'file2',
            })

            -- Check that the directory no longer exists
            assert.is.falsy(root.dir('dir2').exists())
        end)

        it('should not prompt and automatically confirm yes if no_prompt == true', function()
            local buf = driver.buffer(editor.open(root.path()))

            -- Ensure we are pointing at the right line
            assert(
                driver.window().move_cursor_to('file1'),
                'Failed to move cursor to line'
            )

            -- Perform remove action
            actions.remove({ no_prompt = true })

            -- Should not have changed buffers
            assert.are.equal(buf.id(), vim.api.nvim_get_current_buf())

            -- Check that our current buffer reflects lack of file
            buf.assert.same({
                'dir1',
                'dir2',
                'file2',
            })

            -- Check that the file was removed
            assert.is.falsy(root.file('file1').exists())
        end)

        it('should do nothing if no specified at prompt', function()
            -- TODO: Is there a way to provide input to the prompt without stubbing it?
            stub(vim.fn, 'confirm', 2)

            local buf = driver.buffer(editor.open(root.path()))

            -- Ensure we are pointing at the right line
            assert(
                driver.window().move_cursor_to('file1'),
                'Failed to move cursor to line'
            )

            -- Perform remove action
            actions.remove()

            -- Should not have changed buffers
            assert.are.equal(buf.id(), vim.api.nvim_get_current_buf())

            -- Check that our current buffer still reflects full directory
            buf.assert.same({
                'dir1',
                'dir2',
                'file1',
                'file2',
            })

            -- Check that the file was not removed
            assert.is.truthy(root.file('file1').exists())
        end)

        it('should do nothing if not in a remote buffer', function()
            local buf = driver.make_buffer('some contents', { modified = false })
            driver.window().set_buf(buf.id())

            -- Perform remove action
            actions.remove({ no_prompt = true })

            -- Should not have changed buffers
            assert.are.equal(buf.id(), vim.api.nvim_get_current_buf())

            -- Buffer contents should remain the same
            buf.assert.same('some contents')
        end)
    end)
end)
