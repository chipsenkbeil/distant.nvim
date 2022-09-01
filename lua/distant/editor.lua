--- Provides editor-oriented operations
local editor = {}

-- Core editor commands
editor.launch = require('distant.editor.launch')
editor.connect = require('distant.editor.connect')
editor.open = require('distant.editor.open')
editor.write = require('distant.editor.write')

-- Search commands
editor.cancel_search = require('distant.editor.cancel_search')
editor.search = require('distant.editor.search')

-- General display commands
editor.show_metadata = require('distant.editor.show.metadata')
editor.show_session_info = require('distant.editor.show.session')
editor.show_system_info = require('distant.editor.show.system')

return editor
