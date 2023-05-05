local Version = require('distant-core').Version

--- Represents the minimum version supported by this plugin.
local MIN_VERSION = Version:parse('0.20.0-alpha.5')

return {
    core     = require('distant-core'),
    editor   = require('distant.editor'),
    fn       = require('distant.fn'),
    nav      = require('distant.nav'),
    settings = require('distant.settings'),
    setup    = require('distant.setup'),
    wrap     = require('distant.wrap'),
    version  = {
        minimum = MIN_VERSION,
    },
}
