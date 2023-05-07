local BufferVar = require('distant-core.vars.buffer_var')

--- @param path string
--- @return string
local function remove_trailing_slash(path)
    local s, _ = string.gsub(path, '[\\/]+$', '')
    return s
end

--- @class distant.core.vars.Buffer
--- @field buf number
--- @field remote_path distant.core.vars.StringBufferVar
--- @field remote_type distant.core.vars.StringBufferVar
--- @field remote_alt_paths distant.core.vars.ListBufferVar
local M = {}
M.__index = M

--- @param opts {buf:number}
--- @return distant.core.vars.Buffer
function M:new(opts)
    local instance = {}
    setmetatable(instance, M)
    instance.buf = opts.buf

    --- NOTE: We are assigning a BufferVar, but giving it the
    ---       fake type of StringBufferVar. This is a workaround
    ---       for the lack of class generics in Lua language server.
    --- @type distant.core.vars.StringBufferVar
    --- @diagnostic disable-next-line:assign-type-mismatch
    instance.remote_path = BufferVar:new({ buf = opts.buf, name = 'remote_path' })

    --- NOTE: We are assigning a BufferVar, but giving it the
    ---       fake type of StringBufferVar. This is a workaround
    ---       for the lack of class generics in Lua language server.
    --- @type distant.core.vars.StringBufferVar
    --- @diagnostic disable-next-line:assign-type-mismatch
    instance.remote_type = BufferVar:new({ buf = opts.buf, name = 'remote_type' })

    --- NOTE: We are assigning a BufferVar, but giving it the
    ---       fake type of StringBufferVar. This is a workaround
    ---       for the lack of class generics in Lua language server.
    --- @type distant.core.vars.ListBufferVar
    --- @diagnostic disable-next-line:assign-type-mismatch
    instance.remote_alt_paths = BufferVar:new({ buf = opts.buf, name = 'remote_alt_paths' })

    return instance
end

--- @return true
function M:is_initialized()
    return self.remote_path:is_set()
end

--- Scans all buffer path variables to see if there is a matching remote path.
--- @param path string
--- @return boolean
function M:has_matching_remote_path(path)
    if not self:is_initialized() or type(path) ~= 'string' or path:len() == 0 then
        return false
    end

    path = remove_trailing_slash(path)

    -- CHECK PRIMARY PATH

    local primary_path = self.remote_path:get()
    if type(primary_path) == 'string' and primary_path:len() > 0 then
        primary_path = remove_trailing_slash(primary_path)

        if path == primary_path then
            return true
        end
    end

    -- CHECK ALT PATHS

    for _, alt_path in ipairs(self.remote_alt_paths:get() or {}) do
        if type(alt_path) == 'string' and alt_path:len() > 0 then
            alt_path = remove_trailing_slash(alt_path)

            if path == alt_path then
                return true
            end
        end
    end

    -- NO MATCH

    return false
end

return M
