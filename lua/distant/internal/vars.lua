local function set_global_var(name, value)
    vim.api.nvim_set_var('distant_' .. name, value)
end

local function global_var(name)
    return vim.api.nvim_get_var('distant_' .. name)
end

local function set_buf_var(buf, name, value)
    vim.api.nvim_buf_set_var(buf, 'distant_' .. name, value)
end

local function buf_var(buf, name)
    return vim.api.nvim_buf_get_var(buf, 'distant_' .. name)
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
vars.buf.remote_path = function(buf)
    return buf_var(buf or 0, 'remote_path')
end

return vars
