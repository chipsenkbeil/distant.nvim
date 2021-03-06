local u = require('distant.utils')

--- Contains operations to apply against a global collection of functions
local data = {}

-- Inner data that is not directly exposed
local inner = {}

--- Inserts value into the global storage, returning an id for future reference
---
--- @param value any The value to store
--- @param prefix? string Optional prefix to add to the id created for the value
--- @return string #A unique id associated with the value
data.insert = function(value, prefix)
    prefix = prefix or 'data_'
    local id = prefix .. u.next_id()
    inner[id] = value
    return id
end

--- Removes the value with the specified id
---
--- @param id string The id associated with the value
--- @return any? #The removed value, if any
data.remove = function(id)
    return data.set(id, nil)
end

--- Updates data by its id
---
--- @param id string The id associated with the value
--- @param value any The new value
--- @return any? #The old value, if any
data.set = function(id, value)
    local old_value = inner[id]
    inner[id] = value
    return old_value
end

--- Retrieves value by its id
---
--- @param id string The id associated with the value
--- @return any? #The value if found
data.get = function(id)
    return inner[id]
end

--- Checks whether value with the given id exists
---
--- @param id string The id associated with the value
--- @return boolean #True if it exists, otherwise false
data.has = function(id)
    return inner[id] ~= nil
end

--- Retrieves a key mapping around some value by the value's id,
--- assuming that the value will be a function that can be invoked
---
--- @param id number The id associated with the value
--- @param args? string[] #Arguments to feed directly to the value as a function
--- @return string #The mapping that would invoke the value with the given id
data.get_as_key_mapping = function(id, args)
    args = table.concat(args or {}, ',')
    return 'lua require("distant.data").get("' .. id .. '")(' .. args .. ')'
end

return data
