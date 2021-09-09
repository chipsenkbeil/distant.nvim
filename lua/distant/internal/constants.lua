local constants = {}

--- Represents the name of the binary the plugin talks to
constants.BINARY_NAME = 'distant'

--- Represents the maximum time (in milliseconds) before a request times out
constants.MAX_TIMEOUT = 10000

--- Represents the time (in milliseconds) to wait before checking if a response
--- has been returned
constants.TIMEOUT_INTERVAL = 200

--- Represents the minimum support version of the binary that this plugin requires
--- Format is {major, minor, patch}
constants.MIN_SUPPORTED_VERSION = {0, 13, 1}

return constants
