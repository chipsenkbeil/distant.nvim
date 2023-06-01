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

    it('should not reset the modified flag if unsuccessful', function()
        -- Create a remote buffer
        local buf = utils.make_buffer({ 'some content', 'in a buffer' })

        local result = editor.write({ buf = buf })
        assert.equal(result, false)
    end)
end)
