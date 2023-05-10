local Version = require('distant-core').Version

--- Represents the minimum version of the CLI supported by this plugin.
local MIN_VERSION = Version:parse('0.20.0-alpha.5')

--- Represents the version of the plugin (not CLI).
local PLUGIN_VERSION = Version:parse('0.2.0-alpha.1')

return {
    minimum = MIN_VERSION,
    plugin = PLUGIN_VERSION,
}
