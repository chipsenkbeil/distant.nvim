--- @class BaseArgs
--- @field __internal string[]
local BaseArgs = {
    __internal = {}
}

--- Creates a new instance of args
function BaseArgs:new()
    local instance = {}
    setmetatable(instance, self)
    self.__index = self
    return instance
end

--- Adds a new argument to the list
--- @param key string #the key to add
--- @param value? string #optional value for argument
--- @param verbatim? boolean #if true, does not transform key casing and uses as is
--- @return BaseArgs #reference to self
function BaseArgs:add(key, value, verbatim)
    if not key then
        return self
    end

    local key_label = key
    if not verbatim then
        key_label = key:gsub('_', '-')
    end

    table.insert(self.__internal, '--' .. key_label)
    if value then
        table.insert(self.__internal, tostring(value))
    end

    return self
end

--- Returns args as a string for use in a cmd
--- @return string
function BaseArgs:__tostring()
    return table.concat(self.__internal, ' ')
end

return BaseArgs
