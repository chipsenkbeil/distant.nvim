--- Provides editor-oriented operations.
--- @class distant.plugin.Editor
local M         = {}

-- Core editor commands
M.launch        = require('distant.editor.launch')
M.connect       = require('distant.editor.connect')
M.open          = require('distant.editor.open')
M.watch         = require('distant.editor.watch')
M.write         = require('distant.editor.write')

-- Search commands
M.search        = require('distant.editor.search').search
M.cancel_search = require('distant.editor.search').cancel

-- General display commands
M.show_metadata = require('distant.editor.show_metadata')

return M
