local editor = require('distant.editor')
local plugin = require('distant')
local utils  = require('spec.unit.utils')

describe('distant.editor.write', function()
    it('should do nothing if the buffer is not representing a remote path', function()
        -- Create a local buffer
        local buf = utils.make_buffer({ 'some content', 'in a buffer' })

        -- Write to the buffer and verify that we did nothing
        local result = editor.write({ buf = buf })
        assert.is.falsy(result)
    end)

    it('should write all lines of the buffer to the remote file', function()
        -- Create a local buffer
        local buf = utils.make_buffer({ 'some content', 'in a buffer' })

        -- Populate a fake client in our plugin to make sure that
        -- we can stub out the write operation
        plugin.__manager = nil

        -- Specify that our buffer represents a remote file
        plugin.buf(buf).set_data({
            client_id = 123,
            path = '/some/remote/path',
            alt_paths = { '.' },
            type = 'file',
        })

        -- Write to the buffer and verify that we invoked our API underneath
        local result = editor.write({ buf = buf })
        assert.is.truthy(result)
    end)

    it('should not reset the modified flag if unsuccessful', function()
        -- Create a remote buffer
        local buf = utils.make_buffer({ 'some content', 'in a buffer' })

        local result = editor.write({ buf = buf })
        assert.equal(result, false)
    end)
end)
