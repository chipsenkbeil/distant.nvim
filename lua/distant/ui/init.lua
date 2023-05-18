local colors = require('distant.ui.colors')

--- @class distant.plugin.Ui
local M = {}

function M.initialize()
    -- Activate our colors
    colors.initialize()
end

return M
