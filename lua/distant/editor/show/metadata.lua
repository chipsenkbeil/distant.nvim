local fn = require('distant.fn')
local log = require('distant.log')
local ui = require('distant.internal.ui')

--- Opens a new window to show metadata for some path
---
--- @param path string Path to file/directory/symlink to show
--- @param opts.canonicalize boolean If true, includes a canonicalized version
---        of the path in the response
--- @param opts.timeout number Maximum time to wait for a response (optional)
--- @param opts.interval number Time in milliseconds to wait between checks for a response (optional)
return function(path, opts)
    log.trace('editor.show.metadata(' .. vim.inspect(path) .. ')')
    assert(type(path) == 'string', 'path must be a string')
    opts = opts or {}

    local err, metadata = fn.metadata(path, opts)
    if metadata == nil then
        local msg = {path .. ' does not exist'}
        if err then
            table.insert(msg, err)
        end
        ui.show_msg(msg, 'err')
        return
    end

    local lines = {}
    table.insert(lines, 'Path: "' .. path .. '"')
    if metadata.canonicalized_path then
        table.insert(lines, 'Canonicalized Path: "' .. metadata.canonicalized_path .. '"')
    end
    table.insert(lines, 'File Type: ' .. metadata.file_type)
    table.insert(lines, 'Len: ' .. tostring(metadata.len) .. ' bytes')
    table.insert(lines, 'Readonly: ' .. tostring(metadata.readonly))
    if metadata.created ~= nil then
        table.insert(lines, 'Created: ' .. vim.fn.strftime(
            '%c',
            math.floor(metadata.created / 1000.0)
        ))
    end
    if metadata.accessed ~= nil then
        table.insert(lines, 'Last Accessed: ' .. vim.fn.strftime(
            '%c',
            math.floor(metadata.accessed / 1000.0)
        ))
    end
    if metadata.modified ~= nil then
        table.insert(lines, 'Last Modified: ' .. vim.fn.strftime(
            '%c',
            math.floor(metadata.modified / 1000.0)
        ))
    end

    ui.show_msg(lines)
end
