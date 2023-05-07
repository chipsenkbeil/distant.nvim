local make_assert = require('spec.e2e.driver.assert')

--- @class spec.e2e.LocalFile
--- @field private __path string #path on the local machine
local M = {}
M.__index = M

--- Creates a new instance of a reference to a local file.
--- @param opts {path:string}
--- @return spec.e2e.LocalFile
function M:new(opts)
    local instance = {}
    setmetatable(instance, M)
    instance.__path = assert(opts.path, 'Missing path')
    instance.assert = make_assert({
        get_lines = function() return M.lines(instance) or {} end
    })
    return instance
end

--- Return path of file on local machine
--- @return string
function M:path()
    return self.__path
end

--- Return canonicalized path of file on local machine
--- @return string|nil
function M:canonicalized_path()
    return vim.loop.fs_realpath(self.__path)
end

--- Read local file into list of lines
--- @param opts? spec.e2e.IgnoreErrorsOpts
--- @return string[]|nil
function M:lines(opts)
    local contents = self:read(opts)

    if contents then
        return vim.split(contents, '\n', { plain = true })
    end
end

--- Read local file into string
--- @param opts? spec.e2e.IgnoreErrorsOpts
--- @return string|nil
function M:read(opts)
    opts = opts or {}

    -- Read the file into a string
    local f = io.open(self.__path, 'rb')
    if not opts.ignore_errors then
        assert(f, 'Failed to open ' .. self.__path)
    end

    if f then
        local contents = f:read(_VERSION <= 'Lua 5.2' and '*a' or 'a')
        f:close()
        if type(contents) == 'string' then
            return contents
        end
    end
end

--- Writes local file with contents
--- @param contents string|string[]
--- @param opts? spec.e2e.IgnoreErrorsOpts
function M:write(contents, opts)
    opts = opts or {}

    if type(contents) == 'table' then
        contents = table.concat(contents, '\n')
    end

    local f = io.open(self.__path, 'w')
    if not opts.ignore_errors then
        assert(f, 'Failed to open ' .. self.__path)
    end

    if f then
        f:write(contents)
        f:flush()
        f:close()
    end
end

return M
