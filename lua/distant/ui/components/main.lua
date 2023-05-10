local Ui = require('distant-core.ui')

local Connections = require('distant.ui.components.main.connections')
local SystemInfo = require('distant.ui.components.main.system_info')

--- @param state distant.ui.State
--- @return distant.core.ui.INode
return function(state)
    return Ui.CascadingStyleNode({ 'INDENT' }, {
        Ui.When(state.view.current == 'Connections', function()
            return Connections(state)
        end),
        Ui.When(state.view.current == 'System Info', function()
            return SystemInfo(state)
        end),
    })
end
