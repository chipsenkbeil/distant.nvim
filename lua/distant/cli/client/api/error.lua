--- @class ApiError
--- @field kind string
--- @field description string
local Error = {}
Error.__index = Error

--- Creates a new API error
--- @param opts {kind:string, description:string}
--- @return ApiError
function Error:new(opts)
    vim.validate({
        kind = { opts.kind, 'string' },
        description = { opts.description, 'string' },
    })

    local instance = {}
    setmetatable(instance, Error)

    instance.kind = opts.kind
    instance.description = opts.description

    return instance
end

--- Returns an error with an unknown kind and - optionally - empty description
--- @param description string|nil
function Error:unknown(description)
    return Error:new({
        kind = 'unknown',
        description = description or '',
    })
end

--- Converts error to its underlying description if non-empty, otherwise returns
--- the kind of error
--- @return string
function Error:__tostring()
    if string.len(self.description) > 0 then
        return self.description
    else
        return self.kind
    end
end

return Error
