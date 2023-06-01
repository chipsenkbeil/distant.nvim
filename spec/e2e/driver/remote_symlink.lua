--- @class spec.e2e.RemoteSymlink
--- @field private __driver spec.e2e.Driver
--- @field private __path string #path on the remote machine
local M = {}
M.__index = M

--- Creates a new instance of a reference to a remote symlink.
--- @param opts {driver:spec.e2e.Driver, path:string}
--- @return spec.e2e.RemoteSymlink
function M:new(opts)
    local instance = {}
    setmetatable(instance, M)
    instance.__driver = assert(opts.driver, 'Missing driver')
    instance.__path = assert(opts.path, 'Missing path')
    return instance
end

--- Return path of symlink on remote machine
--- @return string
function M:path()
    return self.__path
end

--- Return canonicalized path of symlink on remote machine.
--- @param opts? spec.e2e.IgnoreErrorsOpts
--- @return string|nil
function M:canonicalized_path(opts)
    local os = self.__driver:detect_remote_os()
    local results

    -- On MacOS, `readlink -f` has replaced `realpath`
    if os == 'macos' then
        results = self.__driver:exec('readlink', { '-f', self.__path }, opts)
    else
        results = self.__driver:exec('realpath', { self.__path }, opts)
    end

    if results.success then
        return vim.trim(results.output)
    end
end

--- Return path of source of symlink, if it exists.
--- @param opts? spec.e2e.IgnoreErrorsOpts
--- @return string|nil
function M:source_path(opts)
    local results = self.__driver:exec('readlink', { self.__path }, opts)
    if results.success then
        return vim.trim(results.output)
    end
end

--- Creates the symlink, pointing to the specified location.
--- @param source string #Path that is the source for a symlink (what it points to)
--- @param opts? spec.e2e.IgnoreErrorsOpts
--- @return boolean
function M:make(source, opts)
    local results = self.__driver:exec('ln', { '-s', source, self.__path }, opts)
    return results.success
end

--- Checks if path exists and is a symlink
--- @param opts? spec.e2e.IgnoreErrorsOpts
--- @return boolean
function M:exists(opts)
    local cmd = 'test -L ' .. self.__path .. ' && echo yes || echo no'
    local results = self.__driver:exec('sh', { '-c', '"' .. cmd .. '"' }, opts)
    return vim.trim(results.output) == 'yes'
end

--- Removes the remote symlink at the specified path.
--- @param opts? spec.e2e.IgnoreErrorsOpts
--- @return boolean
function M:remove(opts)
    local results = self.__driver:exec('rm', { '-f', self.__path }, opts)
    return results.success
end

return M
