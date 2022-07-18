local errors = {}

--- @alias ErrorType
--- | 'EX_USAGE' # CLI arguments were incorrect
--- | 'EX_DATAERR' # ...
--- | 'EX_NOINPUT' # ...
--- | 'EX_NOUSER' # User for authentication was not found
--- | 'EX_NOHOST' # Unable to resolve host
--- | 'EX_UNAVAILABLE' # Network was unavailable (could be related to manager or server)
--- | 'EX_SOFTWARE' # Internal software error (e.g. action failed)
--- | 'EX_OSERR' # Arbitrary OS error (e.g. forking failed)
--- | 'EX_IOERR' # Artitrary IO error
--- | 'EX_TEMPFAIL' # Retriable error, usually network timeouts
--- | 'EX_PROTOCOL' # Underlying protocol failure tied to transport
--- | 'EX_NOPERM' # Lacking permission to do something remotely
--- | 'EX_CONFIG' # Configuration file is mis-configured

--- @type table<ErrorType, number>
local ERROR_CODES = {
    EX_USAGE       = 64,
    EX_DATAERR     = 65,
    EX_NOINPUT     = 66,
    EX_NOUSER      = 67,
    EX_NOHOST      = 68,
    EX_UNAVAILABLE = 69,
    EX_SOFTWARE    = 70,
    EX_OSERR       = 71,
    EX_IOERR       = 74,
    EX_TEMPFAIL    = 75,
    EX_PROTOCOL    = 76,
    EX_NOPERM      = 77,
    EX_CONFIG      = 78,
}

--- Represents mapping of label -> code
--- @type table<ErrorType, number>
errors.codes = ERROR_CODES

--- Represents mapping of label -> description
--- @type table<ErrorType, string>
local ERROR_CODE_DESCRIPTIONS = {
    EX_USAGE       = 'Arguments missing or bad arguments provided to CLI',
    EX_DATAERR     = '...',
    EX_NOINPUT     = '...',
    EX_NOUSER      = 'User does not exist for authentication',
    EX_NOHOST      = 'Failed to resolve a host',
    EX_UNAVAILABLE = 'Manager or server is unavailable',
    EX_SOFTWARE    = 'Internal software error (e.g. action failed)',
    EX_OSERR       = 'General OS error (e.g. fork failed)',
    EX_IOERR       = 'General IO error',
    EX_TEMPFAIL    = 'Request timed out',
    EX_PROTOCOL    = 'Transport protocol error',
    EX_NOPERM      = 'Lacking permission',
    EX_CONFIG      = 'Config file misconfigured',
}

--- Looks up if the error code is the specified error type
--- @param errno number
--- @param ty ErrorType
--- @return boolean
errors.is_type = function(errno, ty)
    return errors.lookup_type(errno) == ty
end

--- Looks up an error type by the error number
--- @param errno number
--- @return ErrorType|nil
errors.lookup_type = function(errno)
    for ty, code in pairs(ERROR_CODES) do
        if code == errno then
            return ty
        end
    end
end

--- Looks up an error's description by its type
--- @param ty ErrorType
--- @return string|nil
errors.description_by_type = function(ty)
    return ERROR_CODE_DESCRIPTIONS[ty]
end

--- Looks up an error's description by its code
--- @param code number
--- @return string|nil
errors.description_by_code = function(code)
    return errors.description_by_type(errors.lookup_type(code))
end

return errors
