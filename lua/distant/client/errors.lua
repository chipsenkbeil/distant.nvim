local errors = {}

local ERROR_CODES = {
    EX_USAGE       = 64,
    EX_DATAERR     = 65,
    EX_NOINPUT     = 66,
    EX_NOHOST      = 68,
    EX_UNAVAILABLE = 69,
    EX_SOFTWARE    = 70,
    EX_OSERR       = 71,
    EX_IOERR       = 74,
    EX_TEMPFAIL    = 75,
    EX_PROTOCOL    = 76,
}

--- Represents mapping of label -> code
errors.codes = ERROR_CODES

--- Represents mapping of label -> description
local ERROR_CODE_DESCRIPTIONS = {
    EX_USAGE       = 'Arguments missing or bad arguments provided to CLI',
    EX_DATAERR     = 'Bad data received not in UTF-8 format or transport data is bad',
    EX_NOINPUT     = 'Not getting expected data from launch',
    EX_NOHOST      = 'Failed to resolve a host',
    EX_UNAVAILABLE = 'IO error encountered where connection is problem',
    EX_SOFTWARE    = 'Internal client error, probably about joining tasks',
    EX_OSERR       = 'Fork failed',
    EX_IOERR       = 'Catchall for IO errors',
    EX_TEMPFAIL    = 'Request timed out',
    EX_PROTOCOL    = 'Transport error',
}

--- Looks up an error type by the error number
--- @param errno number
--- @return string|nil
errors.lookup_type = function(errno)
    for ty, code in pairs(ERROR_CODES) do
        if code == errno then
            return ty
        end
    end
end

--- Looks up an error's description by its type
--- @param ty string
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
