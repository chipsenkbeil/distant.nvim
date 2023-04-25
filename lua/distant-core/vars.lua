local utils = require('distant-core.utils')

--- @class BufVar
--- @field set fun(value:any) #sets buffer variable to value
--- @field get fun():any #retrieves buffer variable value (or nil if not set)
--- @field set_if_unset fun(value:any) #sets buffer variable to value if it is not set
--- @field is_set fun():boolean #returns true if variable is set
--- @field is_unset fun():boolean #returns true if variable is not set
--- @field unset fun() #unsets the variable

--- @alias BufVarType 'string'|'number'|'boolean'

--- @param buf number #buffer number
--- @param name string #name of the variable
--- @param ty BufVarType|BufVarType[] #type(s) that the variable can be
--- @param set_map nil|fun(...):... #if provided, maps input to output of set(...)
--- @return BufVar
local function buf_var(buf, name, ty, set_map)
    --- Fails with error if not valid type
    --- @type fun(value:any)
    local validate_var

    set_map = function(...) return ... end

    if type(ty) == 'table' and vim.tbl_islist(ty) then
        validate_var = function(value)
            for _, t in ipairs(ty) do
                if type(value) == t then
                    return
                end
            end

            error('value of type ' .. type(value) .. ' was not any of ' .. table.concat(ty, ', '))
        end
    elseif type(ty) == 'string' then
        validate_var = function(value)
            assert(type(value) == ty, 'value of type ' .. type(value) .. ' was not ' .. ty)
        end
    else
        error('BufVar(' .. tostring(name) .. ', ' .. tostring(ty) .. ') -- type must be string or string[]')
    end

    local function set_buf_var(value)
        if value ~= nil then
            validate_var(value)
            value = set_map(value)
        end

        vim.api.nvim_buf_set_var(buf, 'distant_' .. name, value)
    end

    local function get_buf_var()
        local ret, value = pcall(vim.api.nvim_buf_get_var, buf, 'distant_' .. name)
        if ret then
            return value
        end
    end

    local function is_buf_var_set()
        return get_buf_var() ~= nil
    end

    local function set_buf_var_if_unset(value)
        if not is_buf_var_set() then
            set_buf_var(value)
        end
    end

    return {
        is_set = is_buf_var_set,
        is_unset = function() return not is_buf_var_set() end,
        get = get_buf_var,
        set = set_buf_var,
        set_if_unset = set_buf_var_if_unset,
        unset = function() return set_buf_var(nil) end,
    }
end

--- Ensure that path does not end with separator / or \ as
--- the stored paths don't end with those, either
--- @param path string
--- @return string
local function clean_path(path)
    if type(path) == 'string' then
        return string.gsub(path, '[\\/]+$', '')[1]
    else
        return ''
    end
end

-- GLOBAL DEFINITIONS ---------------------------------------------------------

--- Contains getters and setters for variables used by this plugin
local M = {}

-- BUF LOCAL DEFINITIONS ------------------------------------------------------

M.Buf = {}
M.Buf.__index = M.buf
M.Buf.__call = function(_, bufnr)
    bufnr = bufnr or 0
    local buf_vars = {
        remote_path = buf_var(bufnr, 'remote_path', 'string', clean_path),
        remote_type = buf_var(bufnr, 'remote_type', 'string'),
        remote_alt_paths = buf_var(bufnr, 'remote_alt_paths', 'table', function(paths)
            if vim.tbl_islist(paths) then
                return vim.tbl_map(clean_path, paths)
            end
        end),
    }

    --- Returns true if remote buffer variables have been set
    --- @return boolean
    buf_vars.is_initialized = function()
        return buf_vars.remote_path.is_set()
    end

    --- @param path string
    --- @return boolean
    buf_vars.has_matching_remote_path = function(path)
        if buf_vars.is_initialized() then
            local cleaned_path = clean_path(path)

            local primary_path = buf_vars.remote_path.get()
            local cleaned_primary_path = clean_path(primary_path)
            local matches_primary_path = primary_path == path or cleaned_primary_path == cleaned_path
            if matches_primary_path then
                return true
            end

            local alt_paths = M.buf(bufnr).remote_alt_paths.get() or {}
            if alt_paths[path] ~= nil or alt_paths[cleaned_path] ~= nil then
                return true
            end
        end

        return false
    end

    return buf_vars
end

M.buf = (function()
    local instance = {}
    setmetatable(instance, M.Buf)

    --- Search all buffers for path or alt path match
    --- @param path string #looks for distant://path and path itself
    --- @return number|nil #bufnr of first match if found
    instance.find_with_path = function(path)
        path = utils.strip_prefix(path, 'distant://')

        -- Check if we have a buffer in the form of distant://path
        local bufnr = vim.fn.bufnr('^distant://' .. path .. '$', 0)
        if bufnr ~= -1 then
            return bufnr
        end

        -- Otherwise, we look through all buffers to see if the path is set
        -- as the primary or one of the alternate paths
        --- @diagnostic disable-next-line:redefined-local
        for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
            if M.buf(bufnr).has_matching_remote_path(path) then
                return bufnr
            end
        end
    end

    return instance
end)()

return M
