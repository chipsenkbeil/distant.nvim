local make_assert = require('spec.e2e.driver.assert')

--- @class spec.e2e.Buffer
--- @field private __id  number
--- @field assert spec.e2e.Assert
local M = {}
M.__index = M

--- Creates a new instance of a reference to a local file.
--- @param opts {id:number}
--- @return spec.e2e.Buffer
function M:new(opts)
    local instance = {}
    setmetatable(instance, M)
    instance.__id = assert(opts.id, 'Missing id')
    instance.assert = make_assert({
        get_lines = function() return M.lines(instance) or {} end
    })
    return instance
end

--- Returns buffer id.
--- @return number
function M:id()
    return self.__id
end

--- Return name of buffer.
--- @return string
function M:name()
    return vim.api.nvim_buf_get_name(self.__id)
end

--- Return filetype of buffer.
--- @return string
function M:filetype()
    return vim.api.nvim_buf_get_option(self.__id, 'filetype')
end

--- Return buftype of buffer.
--- @return string
function M:buftype()
    return vim.api.nvim_buf_get_option(self.__id, 'buftype')
end

--- Return if modifiable.
--- @return boolean
function M:modifiable()
    return vim.api.nvim_buf_get_option(self.__id, 'modifiable')
end

--- Return buffer variable with given name. Throws error if variable missing.
--- @return any
function M:get_var(name)
    return vim.api.nvim_buf_get_var(self.__id, name)
end

--- Return buffer variable with given name. Returns nil if variable missing.
--- @return any|nil
function M:try_get_var(name)
    local success, data = pcall(self.get_var, self, name)
    if success then
        return data
    end
end

--- Return the remote path associated with the buffer, if it has one.
--- @return string|nil
function M:remote_path()
    return self:try_get_var('distant_remote_path')
end

--- Return the remote type associated with the buffer, if it has one.
--- @return string|nil
function M:remote_type()
    return self:try_get_var('distant_remote_type')
end

--- Reads lines from buffer as a single string separated by newlines.
--- @return string
function M:contents()
    return table.concat(self:lines(), '\n')
end

--- Read lines from buffer.
--- @return string[]
function M:lines()
    return vim.api.nvim_buf_get_lines(
        self.__id,
        0,
        vim.api.nvim_buf_line_count(self.__id),
        true
    )
end

--- Set lines of buffer.
--- @param lines string[]
--- @param opts? {modified?:boolean}
function M:set_lines(lines, opts)
    opts = opts or {}

    vim.api.nvim_buf_set_lines(
        self.__id,
        0,
        vim.api.nvim_buf_line_count(self.__id),
        true,
        lines
    )

    if type(opts.modified) == 'boolean' then
        vim.api.nvim_buf_set_option(self.__id, 'modified', opts.modified)
    end
end

--- Return if buffer is focused.
--- @return boolean
function M:is_focused()
    return self.__id == vim.api.nvim_get_current_buf()
end

return M
