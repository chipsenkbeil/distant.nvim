local log = require('distant-core').log
local Ui  = require('distant.ui')

--- @class EditorShowSystemOpts
--- @field timeout? number #Maximum time to wait for a response
--- @field interval? number #Time in milliseconds to wait between checks for a response

--- Opens a new window to display system info
--- @param opts? EditorShowSystemOpts
return function(opts)
    opts = opts or {}
    log.trace('editor.show.system(%s)', opts)

    Ui.set_view('System Info')
    Ui.open()
end
