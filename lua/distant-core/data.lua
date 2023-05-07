local utils = require('distant-core.utils')

--- Contains operations to apply against a global collection of functions
--- @class distant.core.Data
local M = {}

-- Inner data that is not directly exposed
local inner = {}

--- Inserts value into the global storage, returning an id for future reference
---
--- @param value any The value to store
--- @param prefix? string Optional prefix to add to the id created for the value
--- @return string #A unique id associated with the value
M.insert = function(value, prefix)
    prefix = prefix or 'data_'
    local id = prefix .. utils.next_id()
    inner[id] = value
    return id
end

--- Removes the value with the specified id
---
--- @param id string The id associated with the value
--- @return any? #The removed value, if any
M.remove = function(id)
    return M.set(id, nil)
end

--- Updates data by its id
---
--- @param id string The id associated with the value
--- @param value any The new value
--- @return any? #The old value, if any
M.set = function(id, value)
    local old_value = inner[id]
    inner[id] = value
    return old_value
end

--- Retrieves value by its id
---
--- @param id string The id associated with the value
--- @return any? #The value if found
M.get = function(id)
    return inner[id]
end

--- Checks whether value with the given id exists
---
--- @param id string The id associated with the value
--- @return boolean #True if it exists, otherwise false
M.has = function(id)
    return inner[id] ~= nil
end

--- Retrieves a key mapping around some value by the value's id,
--- assuming that the value will be a function that can be invoked
---
--- @param id number|string The id associated with the value
--- @param args? string[] #Arguments to feed directly to the value as a function
--- @return string #The mapping that would invoke the value with the given id
M.get_as_key_mapping = function(id, args)
    ---@diagnostic disable-next-line:redefined-local
    local id = tostring(id)

    ---@diagnostic disable-next-line:redefined-local
    local args = table.concat(args or {}, ',')

    return 'lua require("distant-core.data").get("' .. id .. '")(' .. args .. ')'
end

return M
