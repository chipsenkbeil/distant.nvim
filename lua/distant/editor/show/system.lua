local fn = require('distant.fn')
local log = require('distant.log')
local ui = require('distant.ui')

--- @class EditorShowSystemOpts
--- @field timeout? number #Maximum time to wait for a response
--- @field interval? number #Time in milliseconds to wait between checks for a response

--- Opens a new window to display system info
--- @param opts? EditorShowSystemOpts
return function(opts)
    opts = opts or {}
    log.trace('editor.show.system(%s)', opts)
    vim.validate({ opts = { opts, 'table' } })

    local indent = '    '
    local err, info = fn.system_info(opts)
    assert(not err, err)

    if info ~= nil then
        ui.show_msg({
            '= System Info =';
            '';
            indent .. '* Family      = "' .. info.family .. '"';
            indent .. '* OS          = "' .. info.os .. '"';
            indent .. '* Arch        = "' .. info.arch .. '"';
            indent .. '* Current Dir = "' .. info.current_dir .. '"';
            indent .. '* Main Sep    = "' .. info.main_separator .. '"';
        })
    end
end
