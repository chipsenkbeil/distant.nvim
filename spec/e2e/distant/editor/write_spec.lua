local editor = require('distant.editor')
local Driver = require('spec.e2e.driver')

describe('distant.editor.write', function()
    --- @type spec.e2e.Driver, spec.e2e.RemoteFile, spec.e2e.LocalFile
    local driver, remote_file, local_file

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
        remote_file = driver:new_file_fixture({
            ext = 'txt',
            lines = { 'I am a remote file!' },
        })
        local_file = driver:new_local_file_fixture({
            ext = 'txt',
            lines = { 'I am a local file!' },
        })
    end)

    after_each(function()
        -- Will remove all fixtures
        driver:teardown()
    end)

    it('should do nothing for a local buffer', function()
        -- Load the local file into a buffer
        vim.cmd(':edit ' .. local_file:path())
        local buffer = driver:buffer()

        -- Verify we loaded the local file
        buffer.assert.same({ 'I am a local file!' })

        -- Modify the contents
        buffer:set_lines({ 'I have been edited!' }, { modified = true })

        -- Attempt to write the content, which will just do nothing
        assert.is.falsy(editor.write(buffer:id()))

        -- Verify that our local file has not changed
        local_file.assert.same({ 'I am a local file!' })
    end)

    it('should update the remote file using the buffer\'s contents', function()
        -- Load the remote file into a buffer
        local buffer = driver:buffer(editor.open(remote_file:path()))
        assert.is.falsy(buffer:is_modified())

        -- Verify we loaded the remote file
        buffer.assert.same({ 'I am a remote file!' })

        -- Modify the contents
        buffer:set_lines({ 'I have been edited!' }, { modified = true })
        assert.is.truthy(buffer:is_modified())

        -- Attempt to write the content
        assert.is.truthy(editor.write(buffer:id()))

        -- Verify buffer is no longer modified
        assert.is.falsy(buffer:is_modified())

        -- Verify that our remote file has changed
        remote_file.assert.same({ 'I have been edited!' })
    end)
end)
