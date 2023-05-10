local Ui = require('distant-core.ui')
local p = require('distant.ui.palette')

--- @param state distant.ui.State
--- @return distant.core.ui.INode
return function(state)
    local content = Ui.HlTextNode {
        { p.Bold 'TODO: Implement' },
    }

    return Ui.Node {
        Ui.EmptyLine(),
        content,
        Ui.EmptyLine(),
    }
end
