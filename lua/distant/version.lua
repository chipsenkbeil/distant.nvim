local Version = require('distant-core').Version

--- Represents the minimum version supported by this plugin.
local MIN_VERSION = Version:parse('0.20.0-alpha.5')

return {
    minimum = MIN_VERSION,
}
