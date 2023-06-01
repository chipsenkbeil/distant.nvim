local colors = require('distant.ui.colors')

--- @class distant.plugin.Ui
local M = {}

--- Initializes the user interface. Needed for colors and other settings to work properly.
function M.initialize()
    -- Activate our colors
    colors.initialize()
end

return M
