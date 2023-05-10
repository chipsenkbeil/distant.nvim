local colors = require('distant.ui.colors')

--- @class distant.Ui
local M = {}

function M.initialize()
    -- Activate our colors
    colors.initialize()
end

function M.close()
    local api = require('distant.ui.instance')
    api.close()
end

function M.open()
    local api = require('distant.ui.instance')

    api.window.open()

    -- Atempt to load our system information the
    -- first time we open the window
    --
    -- NOTE: Must be invoked after opening window
    --       as the effect handlers aren't set
    --       until after it is opened!
    api.dispatch('RELOAD_TAB', {
        tab = 'System Info',
        force = false,
    })
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
