local fn  = require('distant.fn')
local log = require('distant-core').log
local ui  = require('distant-core').ui

--- Opens a new window to show metadata for some path
return function(opts)
    opts = opts or {}
    local path = opts.path
    if not path then
        error('opts.path is missing')
    end
    log.fmt_trace('editor.show.metadata(%s)', opts)

    local err, metadata = fn.metadata(opts)
    if metadata == nil then
        local msg = { path .. ' does not exist' }
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
