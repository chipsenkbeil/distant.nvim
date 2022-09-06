--- @class BaseCmd
--- @field __cmd string
--- @field __internal string[]
--- @field __allowed table<string, boolean>|nil
local BaseCmd = {}
BaseCmd.__index = BaseCmd

--- @class BaseCmdNewOpts
--- @field allowed? string[] #if provided, will restrict cmd set to only those in allowed list

--- Creates a new instance of cmd
--- @param cmd string
--- @param opts? BaseCmdNewOpts
function BaseCmd:new(cmd, opts)
    opts = opts or {}

    local instance = {}
    setmetatable(instance, BaseCmd)
    instance.__cmd = cmd
    instance.__internal = {}

    if vim.tbl_islist(opts.allowed) then
        instance.__allowed = {}
        for _, key in ipairs(opts.allowed) do
            instance.__allowed[key] = true
        end
    end

    return instance
end

--- Sets multiple arguments using the given table
--- @param tbl table<string, boolean|string>
--- @return BaseCmd #reference to self
function BaseCmd:set_from_tbl(tbl)
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
--- @return BaseCmd #reference to self
function BaseCmd:set(key, value, verbatim)
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
--- @return BaseCmd #reference to self
function BaseCmd:clear(key, verbatim)
    if not key then
        return self
    end

    local key_label = key
    if not verbatim then
        key_label = key:gsub('_', '-')
    end

    self.__internal[key_label] = nil
end

--- Converts cmd into a list of string
--- @return string[]
function BaseCmd:as_list()
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

    return lst
end

--- Returns cmd as a string
--- @return string
function BaseCmd:as_string()
    return vim.trim(table.concat(self:as_list(), ' '))
end

--- Returns cmd as a string
--- @return string
function BaseCmd:__tostring()
    return self:as_string()
end

return BaseCmd
