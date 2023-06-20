--- @enum distant.core.api.error.Kind
local ERROR_KIND = {
    not_found          = 'not_found',
    permission_denied  = 'permission_denied',
    connection_refused = 'connection_refused',
    connection_reset   = 'connection_reset',
    connection_aborted = 'connection_aborted',
    not_connected      = 'not_connected',
    addr_in_use        = 'addr_in_use',
    addr_not_available = 'addr_not_available',
    broken_pipe        = 'broken_pipe',
    already_exists     = 'already_exists',
    would_block        = 'would_block',
    invalid_input      = 'invalid_input',
    invalid_data       = 'invalid_data',
    timed_out          = 'timed_out',
    write_zero         = 'write_zero',
    interrupted        = 'interrupted',
    other              = 'other',
    unexpected_eof     = 'unexpected_eof',
    unsupported        = 'unsupported',
    out_of_memory      = 'out_of_memory',
    loop               = 'loop',
    task_cancelled     = 'task_cancelled',
    task_panicked      = 'task_panicked',
    unknown            = 'unknown',
}

--- @type { [string]: {label:string, explanation:string} }
local ERROR_KIND_DETAILS = {
    not_found          = {
        label = 'Not Found',
        explanation = 'An entity was not found, often a file',
    },
    permission_denied  = {
        label = 'Permission Denied',
        explanation = 'The operation lacked the necessary privileges to complete',
    },
    connection_refused = {
        label = 'Connection Refused',
        explanation = 'The connection was refused by the remote server',
    },
    connection_reset   = {
        label = 'Connection Reset',
        explanation = 'The connection was reset by the remote server',
    },
    connection_aborted = {
        label = 'Connection Aborted',
        explanation = 'The connection was aborted (terminated) by the remote server',
    },
    not_connected      = {
        label = 'Not Connected',
        explanation = 'The network operation failed because it was not connected yet',
    },
    addr_in_use        = {
        label = 'Address in Use',
        explanation = 'A socket address could not be bound because the address is already in use elsewhere',
    },
    addr_not_available = {
        label = 'Address not Available',
        explanation = 'A nonexistent interface was requested or the requested address was not local',
    },
    broken_pipe        = {
        label = 'Broken Pipe',
        explanation = 'The operation failed because a pipe was closed',
    },
    already_exists     = {
        label = 'Already Exists',
        explanation = 'An entity already exists, often a file',
    },
    would_block        = {
        label = 'Would Block',
        explanation = 'The operation needs to block to complete, but the blocking operation was requested to not occur',
    },
    invalid_input      = {
        label = 'Invalid Input',
        explanation = 'A parameter was incorrect',
    },
    invalid_data       = {
        label = 'Invalid Data',
        explanation = 'Data not valid for the operation were encountered',
    },
    timed_out          = {
        label = 'Timed Out',
        explanation = 'The I/O operation\'s timeout expired, causing it to be cancelled',
    },
    write_zero         = {
        label = 'Write Zero',
        explanation =
        'An error returned when an operation could not be completed because a call to `write` returned `Ok(0)`',
    },
    interrupted        = {
        label = 'Interrupted',
        explanation = 'This operation was interrupted',
    },
    other              = {
        label = 'Other',
        explanation = 'Any I/O error not part of this list',
    },
    unexpected_eof     = {
        label = 'Unexpected End of File',
        explanation =
        'An error returned when an operation could not be completed because an "end of file" was reached prematurely',
    },
    unsupported        = {
        label = 'Unsupported',
        explanation = 'This operation is unsupported on this platform',
    },
    out_of_memory      = {
        label = 'Out of Memory',
        explanation = 'An operation could not be completed, because it failed to allocate enough memory',
    },
    loop               = {
        label = 'Loop',
        explanation = 'When a loop is encountered when walking a directory',
    },
    task_cancelled     = {
        label = 'Task Cancelled',
        explanation = 'When a task is cancelled',
    },
    task_panicked      = {
        label = 'Task Panicked',
        explanation = 'When a task panics',
    },
    unknown            = {
        label = 'Unknown',
        explanation = 'Catchall for an error that has no specific type',
    },
}

-------------------------------------------------------------------------------
--- CLASS
-------------------------------------------------------------------------------

--- @class distant.core.api.Error
--- @field kind distant.core.api.error.Kind
--- @field description string
local M = { kinds = ERROR_KIND }
M.__index = M

--- Creates a new instance of an error.
--- @param opts {kind?:distant.core.api.error.Kind, description?:string}
--- @return distant.core.api.Error
function M:new(opts)
    local instance = {}
    setmetatable(instance, M)
    instance.kind = opts.kind or ERROR_KIND.unknown
    instance.description = opts.description or ''

    return instance
end

--- Reports self as an error.
function M:report()
    -- NOTE: We support calling via `Error.report(err)`,
    --       which means that this can be invokved with a non-error
    --       or nil as a possibility.
    if self and type(self.__tostring) == 'function' then
        error(self:__tostring())
    end
end

--- Returns a human label for an error kind.
--- @return string|nil
function M:kind_label()
    local details = ERROR_KIND_DETAILS[self.kind]
    if details then
        return details.label
    end
end

--- Returns the explanation for what an error's kind means.
--- @return string|nil
function M:kind_explanation()
    local details = ERROR_KIND_DETAILS[self.kind]
    if details then
        return details.explanation
    end
end

-------------------------------------------------------------------------------
--- CONVERSIONS
-------------------------------------------------------------------------------

--- Returns error as a string.
--- @return string
function M:as_string()
    if string.len(self.description) > 0 then
        return '(' .. self.kind .. ') ' .. self.description
    else
        return self.kind
    end
end

--- Returns error as a string.
--- @return string
function M:__tostring()
    return self:as_string()
end

return M
