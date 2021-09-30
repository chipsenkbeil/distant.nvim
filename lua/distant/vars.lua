local function set_buf_var(buf, name, value)
    vim.api.nvim_buf_set_var(buf, 'distant_' .. name, value)
end

local function buf_var(buf, name)
    local ret, path = pcall(vim.api.nvim_buf_get_var, buf, 'distant_' .. name)
    if ret then
        return path
    end
end

-- GLOBAL DEFINITIONS ---------------------------------------------------------

--- Contains getters and setters for variables used by this plugin
local vars = {}

-- BUF LOCAL DEFINITIONS ------------------------------------------------------

-- Getters and setters for buf-local variables
vars.buf = {}

--- Sets the path that this buffer points to remotely
---
--- @param buf number The buffer to assign the variable to,
---        or 0 to use current buffer
--- @param path string The path on the remote machine
vars.buf.set_remote_path = function(buf, path)
    set_buf_var(buf or 0, 'remote_path', path)
end

--- Gets the path that this buffer points to remotely
---
--- @param buf number The buffer where the variable is located,
---        or 0 to use current buffer
--- @return string|nil path The path or nil if not found
vars.buf.remote_path = function(buf)
    return buf_var(buf or 0, 'remote_path')
end

--- Sets the type that this buffer points to remotely
---
--- ### Possible Types
---
--- * dir
--- * file
--- * symlink
---
--- @param buf number The buffer to assign the variable to,
---        or 0 to use current buffer
--- @param ty string|nil The type pointed to on the remote machine
vars.buf.set_remote_type = function(buf, ty)
    if ty ~= nil then
        assert(ty == 'dir' or ty == 'file' or ty == 'symlink', 'Invalid type')
    end

    set_buf_var(buf or 0, 'remote_type', ty)
end

--- Gets the type that this buffer points to remotely
---
--- ### Possible Types
---
--- * dir
--- * file
--- * symlink
---
--- @param buf number The buffer where the variable is located,
---        or 0 to use current buffer
--- @return string|nil path The type or nil if not found
vars.buf.remote_type = function(buf)
    return buf_var(buf or 0, 'remote_type')
end

return vars
