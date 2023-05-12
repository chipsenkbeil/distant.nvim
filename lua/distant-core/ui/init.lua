local animation = require('distant-core.ui.animation')
local nodes = require('distant-core.ui.nodes')
local Window = require('distant-core.ui.window')

return {
    --------------------------------------------------------------------------
    -- PUBLIC ANIMATION API
    --------------------------------------------------------------------------

    animation          = animation,

    --------------------------------------------------------------------------
    -- PUBLIC NODE API
    --------------------------------------------------------------------------

    CascadingStyleNode = nodes.CascadingStyleNode,
    DiagnosticsNode    = nodes.DiagnosticsNode,
    EmptyLine          = nodes.EmptyLine,
    HlTextNode         = nodes.HlTextNode,
    Keybind            = nodes.Keybind,
    Node               = nodes.Node,
    StickyCursor       = nodes.StickyCursor,
    Table              = nodes.Table,
    Text               = nodes.Text,
    VirtualTextNode    = nodes.VirtualTextNode,
    When               = nodes.When,

    --------------------------------------------------------------------------
    -- PUBLIC WINDOW API
    --------------------------------------------------------------------------

    Window             = Window,
}
