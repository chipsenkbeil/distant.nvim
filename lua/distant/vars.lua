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
--- @return BufVar
local function buf_var(buf, name, ty)
    --- Fails with error if not valid type
    --- @type fun(value:any)
    local validate_var

    if vim.tbl_islist(ty) then
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

-- GLOBAL DEFINITIONS ---------------------------------------------------------

--- Contains getters and setters for variables used by this plugin
local vars = {}

-- BUF LOCAL DEFINITIONS ------------------------------------------------------

-- Getters and setters for buf-local variables
vars.buf = function(buf)
    buf = buf or 0
    return {
        remote_path = buf_var(buf, 'remote_path', 'string'),
        remote_type = buf_var(buf, 'remote_type', 'string'),
        remote_initialized = buf_var(buf, 'remote_initialized', 'boolean'),
    }
end

return vars
