local VAR_PREFIX = 'distant_'

--- @class distant.core.vars.BufferVar
--- @field buf number
--- @field name string
local M = {}
M.__index = M

--- @param opts {buf:number, name:string}
--- @return distant.core.vars.BufferVar
function M:new(opts)
    local instance = {}
    setmetatable(instance, M)
    instance.buf = opts.buf
    instance.name = opts.name

    return instance
end

--- Returns full, unique name for variable.
--- @return string
function M:full_name()
    return VAR_PREFIX .. self.name
end

--- @return boolean
function M:is_set()
    return self:get() ~= nil
end

--- @return boolean
function M:is_unset()
    return not self:is_set()
end

--- @return any
function M:get()
    -- NOTE: This function will fail if key not found, so wrap in pcall
    --- @type boolean, string
    local success, value = pcall(vim.api.nvim_buf_get_var, self.buf, self:full_name())
    if success then
        return value
    end
end

--- @param value any
function M:set(value)
    vim.api.nvim_buf_set_var(self.buf, self:full_name(), value)
end

--- Sets the variable value if it is not set.
--- @param value any
function M:set_if_unset(value)
    if not self:is_set() then
        self:set(value)
    end
end

--- Clears the variable.
function M:unset()
    -- NOTE: This function will fail if key not found, so wrap in pcall
    pcall(vim.api.nvim_buf_del_var, self.buf, self:full_name())
end

return M
