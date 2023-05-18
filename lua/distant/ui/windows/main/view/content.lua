local ui          = require('distant-core.ui')

local Connections = require('distant.ui.windows.main.view.content.connections')
local SystemInfo  = require('distant.ui.windows.main.view.content.system_info')

--- @param state distant.ui.State
--- @return distant.core.ui.INode
return function(state)
    return ui.CascadingStyleNode({ 'INDENT' }, {
        ui.When(state.view.current == 'Connections', function()
            return Connections(state)
        end),
        ui.When(state.view.current == 'System Info', function()
            return SystemInfo(state)
        end),
    })
end
