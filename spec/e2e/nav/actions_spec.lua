local editor = require('distant.editor')
local fn = require('distant.fn')
local Driver = require('spec.e2e.driver')

describe('actions', function()
    local driver

    before_each(function()
        driver = Driver:setup()
    end)

    after_each(function()
        -- Will remove all fixtures
        driver:teardown()
    end)

    describe('edit', function()
        it('should open the file under the cursor', function()
            pending('todo')
        end)

        it('should do nothing if not in a remote buffer', function()
            pending('todo')
        end)
    end)

    describe('up', function()
        it('should open the parent directory of an open remote directory', function()
            pending('todo')
        end)

        it('should open the parent directory of an open remote file', function()
            pending('todo')
        end)

        it('should do nothing if not in a remote buffer', function()
            pending('todo')
        end)
    end)

    describe('newfile', function()
        it('should open a new file using the given name', function()
            pending('todo')
        end)

        it('should do nothing if no new name provided', function()
            pending('todo')
        end)

        it('should do nothing if not in a remote buffer', function()
            pending('todo')
        end)
    end)

    describe('mkdir', function()
        it('should create the directory and refresh the current buffer', function()
            pending('todo')
        end)

        it('should log an error if creating the directory failed', function()
            pending('todo')
        end)

        it('should do nothing if no directory name provided', function()
            pending('todo')
        end)

        it('should do nothing if not in a remote buffer', function()
            pending('todo')
        end)
    end)

    describe('rename', function()
        it('should rename the file under the cursor and refresh the current buffer', function()
            pending('todo')
        end)

        it('should rename the directory under the cursor and refresh the current buffer', function()
            pending('todo')
        end)

        it('should log an error if renaming failed', function()
            pending('todo')
        end)

        it('should do nothing if no new name provided', function()
            pending('todo')
        end)

        it('should do nothing if not in a remote buffer', function()
            pending('todo')
        end)
    end)

    describe('remove', function()
        it('should remove the file under cursor and refresh the current buffer', function()
            pending('todo')
        end)

        it('should remove the directory under cursor and refresh the current buffer', function()
            pending('todo')
        end)

        it('should not prompt and automatically confirm yes if no_prompt == true', function()
            pending('todo')
        end)

        it('should log an error if removal failed', function()
            pending('todo')
        end)

        it('should do nothing if no specified at prompt', function()
            pending('todo')
        end)

        it('should do nothing if not in a remote buffer', function()
            pending('todo')
        end)
    end)
end)
