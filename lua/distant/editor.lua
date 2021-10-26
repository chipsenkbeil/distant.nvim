--- Provides editor-oriented operations
local editor = {}

editor.launch = require('distant.editor.launch')
editor.connect = require('distant.editor.connect')
editor.open = require('distant.editor.open')
editor.write = require('distant.editor.write')

editor.show_metadata = require('distant.editor.show.metadata')
editor.show_session_info = require('distant.editor.show.session')
editor.show_system_info = require('distant.editor.show.system')

return editor
