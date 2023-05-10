--- @class distant.Editor
--- Provides editor-oriented operations
local M         = {}

-- Core editor commands
M.launch        = require('distant.editor.launch')
M.connect       = require('distant.editor.connect')
M.open          = require('distant.editor.open')
M.write         = require('distant.editor.write')

-- Search commands
M.search        = require('distant.editor.search')
M.cancel_search = require('distant.editor.cancel_search')

-- General display commands
M.show_metadata = require('distant.editor.show_metadata')

return M
