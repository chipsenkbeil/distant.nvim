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

--- Returns if valid.
--- @return boolean
function M:is_valid()
    return vim.api.nvim_buf_is_valid(self.__id)
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
    local tbl = self:try_get_var('distant')
    if type(tbl) == 'table' then
        return tbl.path
    end
end

--- Return the remote type associated with the buffer, if it has one.
--- @return string|nil
function M:remote_type()
    local tbl = self:try_get_var('distant')
    if type(tbl) == 'table' then
        return tbl.type
    end
end

--- Return the remote mtime associated with the buffer, if it has one.
--- @return integer|nil
function M:remote_mtime()
    local tbl = self:try_get_var('distant')
    if type(tbl) == 'table' then
        return tbl.mtime
    end
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
---
--- === Options ===
---
--- * `force` - if true, will set modfy the buffer even if not modifiable.
--- * `modified` - if provided, will update the modified status accordingly.
---
--- @param lines string[]
--- @param opts? {force?:boolean, modified?:boolean}
function M:set_lines(lines, opts)
    opts = opts or {}

    -- Save current modifiable state, ensuring buffer is modifiable
    -- if force is true
    local modifiable = self:modifiable()
    if opts.force then
        vim.api.nvim_buf_set_option(self.__id, 'modifiable', true)
    end

    -- Write the lines to the buffer, overwriting any existing lines
    vim.api.nvim_buf_set_lines(self.__id, 0, -1, false, lines)

    -- Restore old value if forced to change
    if opts.force then
        vim.api.nvim_buf_set_option(self.__id, 'modifiable', modifiable)
    end

    -- If provided, overwrite modified state, which can be helpful
    -- if we want to write lines without indicating the buffer
    -- was modified
    if type(opts.modified) == 'boolean' then
        vim.api.nvim_buf_set_option(self.__id, 'modified', opts.modified)
    end
end

--- Return if buffer is focused.
--- @return boolean
function M:is_focused()
    return self.__id == vim.api.nvim_get_current_buf()
end

--- Return true if buffer is marked as modified.
--- @return boolean
function M:is_modified()
    return vim.api.nvim_buf_get_option(self.__id, 'modified') == true
end

return M
