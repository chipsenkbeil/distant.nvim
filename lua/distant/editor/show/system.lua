local fn = require('distant.fn')
local log = require('distant.log')
local ui = require('distant.ui')

--- Opens a new window to display system info
---
--- @param opts.timeout number Maximum time to wait for a response (optional)
--- @param opts.interval number Time in milliseconds to wait between checks for a response (optional)
return function(opts)
    opts = opts or {}
    log.trace('editor.show.system(%s)', opts)

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
