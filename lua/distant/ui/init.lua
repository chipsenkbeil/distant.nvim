--- @class distant.Ui
local M = {}

function M.close()
    local api = require('distant.ui.instance')
    api.close()
end

function M.open()
    local api = require('distant.ui.instance')
    --[[ require('mason-registry').refresh(function()
    end) ]]
    api.window.open()
end

---@param view string
function M.set_view(view)
    local api = require('distant.ui.instance')
    api.set_view(view)
end

---@param tag any
function M.set_sticky_cursor(tag)
    local api = require('distant.ui.instance')
    api.set_sticky_cursor(tag)
end

return M
