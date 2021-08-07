--- Provides editor-oriented operations
local editor = {}

editor.launch = require('distant.editor.launch')
editor.open = require('distant.editor.open')
editor.show_metadata = require('distant.editor.show.metadata')
editor.show_session_info = require('distant.editor.show.session')
editor.show_system_info = require('distant.editor.show.system')

return editor
