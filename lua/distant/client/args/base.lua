--- @class BaseArgs
--- @field __internal string[]
--- @field __allowed table<string, boolean>|nil
local BaseArgs = {
    __internal = {}
}

--- @class BaseArgsNewOpts
--- @field allowed? string[] #if provided, will restrict args set to only those in allowed list

--- Creates a new instance of args
--- @param opts? BaseArgsNewOpts
function BaseArgs:new(opts)
    opts = opts or {}

    local instance = {}
    setmetatable(instance, self)
    self.__index = self

    if vim.tbl_islist(opts.allowed) then
        self.__allowed = {}
        for _, key in ipairs(opts.allowed) do
            self.__allowed[key] = true
        end
    end

    return instance
end

--- Sets multiple arguments using the given table
--- @param tbl table<string, boolean|string>
--- @return BaseArgs #reference to self
function BaseArgs:set_from_tbl(tbl)
    for key, value in pairs(tbl) do
        if value then
            self:set(key, value)
        end
    end

    return self
end

--- Sets an argument
--- @param key string #the key to add
--- @param value? string #optional value for argument
--- @param verbatim? boolean #if true, does not transform key casing and uses as is
--- @return BaseArgs #reference to self
function BaseArgs:set(key, value, verbatim)
    if not key then
        return self
    end

    local key_label = key
    if not verbatim then
        key_label = key:gsub('_', '-')
    end

    -- Ignore if we have an allowlist and this key is not in it
    if self.__allowed and not self.__allowed[key_label] then
        return self
    end

    self.__internal[key_label] = true

    -- If value is truthy and not "true" itself, we assign a value
    if value and type(value) ~= 'boolean' then
        self.__internal[key_label] = tostring(value)
    end

    return self
end

--- Removes an argument
--- @param key string #the key to add
--- @param verbatim? boolean #if true, does not transform key casing and uses as is
--- @return BaseArgs #reference to self
function BaseArgs:clear(key, verbatim)
    if not key then
        return self
    end

    local key_label = key
    if not verbatim then
        key_label = key:gsub('_', '-')
    end

    self.__internal[key_label] = nil
end

--- Returns args as a string for use in a cmd
--- @return string
function BaseArgs:__tostring()
    local args = {}

    for k, v in pairs(self.__internal) do
        table.insert(args, '--' .. k)
        if type(v) == 'string' then
            table.insert(args, v)
        end
    end

    return table.concat(args, ' ')
end

--- Same as __tostring
--- @return string
function BaseArgs:as_string()
    return self:__tostring()
end

return BaseArgs
