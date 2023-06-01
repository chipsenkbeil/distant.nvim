--- @class distant.core.builder.CmdBuilder
--- @field private __cmd string
--- @field private __internal table<string, boolean|string>
--- @field private __tail? string
--- @field private __allowed? table<string, boolean>
local M = {}
M.__index = M

--- Creates a new instance of cmd.
---
--- If `opts` provided, `opts.allowed` will restrict the `set` function to only operate for those in the allowed list.
---
--- @param cmd string|string[]
--- @param opts? {allowed?:string[]}
--- @return distant.core.builder.CmdBuilder
function M:new(cmd, opts)
    opts = opts or {}

    local instance = {}
    setmetatable(instance, M)
    instance.__internal = {}
    instance.__tail = nil

    if type(cmd) == 'table' then
        instance.__cmd = table.concat(cmd, ' ')
    else
        instance.__cmd = cmd
    end

    if vim.tbl_islist(opts.allowed) then
        instance.__allowed = {}
        for _, key in ipairs(opts.allowed) do
            instance.__allowed[key] = true
        end
    end

    return instance
end

--- Sets multiple arguments using the given table.
--- @param tbl table<string, boolean|string>
--- @return distant.core.builder.CmdBuilder #reference to self
function M:set_from_tbl(tbl)
    for key, value in pairs(tbl) do
        if value then
            self:set(key, value)
        end
    end

    return self
end

--- Sets an argument.
--- @param key string #the key to add
--- @param value? boolean|string #optional value for argument
--- @param verbatim? boolean #if true, does not transform key casing and uses as is
--- @return distant.core.builder.CmdBuilder #reference to self
function M:set(key, value, verbatim)
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

--- Sets the tail of the command, which equates to `{cmd} -- {tail}`.
--- @param value string|nil #the tail, if nil then clears the tail
--- @return distant.core.builder.CmdBuilder #reference to self
function M:set_tail(value)
    self.__tail = value
    return self
end

--- Checks if the command has a `key` specified.
--- @param key string
--- @return boolean
function M:has(key)
    return self.__internal[key] ~= nil
end

--- Removes an argument.
--- @param key string #the key to add
--- @param verbatim? boolean #if true, does not transform key casing and uses as is
--- @return distant.core.builder.CmdBuilder #reference to self
function M:clear(key, verbatim)
    if not key then
        return self
    end

    local key_label = key
    if not verbatim then
        key_label = key:gsub('_', '-')
    end

    self.__internal[key_label] = nil

    return self
end

--- Clears the tail of the command.
--- @return distant.core.builder.CmdBuilder #reference to self
function M:clear_tail()
    self.__tail = nil
    return self
end

--- Converts cmd into a list of string.
--- @return string[]
function M:as_list()
    local lst = {}

    -- Break up cmd by whitespace and add each piece individually
    for _, arg in ipairs(vim.split(self.__cmd, ' ', { plain = true, trimempty = true })) do
        table.insert(lst, arg)
    end

    for k, v in pairs(self.__internal) do
        table.insert(lst, '--' .. k)
        if type(v) == 'string' then
            table.insert(lst, v)
        end
    end

    if self.__tail then
        table.insert(lst, '--')
        table.insert(lst, self.__tail)
    end

    return lst
end

--- Returns cmd as a string.
--- @return string
function M:as_string()
    return vim.trim(table.concat(self:as_list(), ' '))
end

--- Returns cmd as a string.
--- @return string
function M:__tostring()
    return self:as_string()
end

return M
