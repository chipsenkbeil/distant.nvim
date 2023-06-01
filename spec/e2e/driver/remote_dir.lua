--- @class spec.e2e.RemoteDir
--- @field private __driver spec.e2e.Driver
--- @field private __path string #path on the remote machine
local M = {}
M.__index = M

--- Creates a new instance of a reference to a remote directory.
--- @param opts {driver:spec.e2e.Driver, path:string}
--- @return spec.e2e.RemoteDir
function M:new(opts)
    local instance = {}
    setmetatable(instance, M)
    instance.__driver = assert(opts.driver, 'Missing driver')
    instance.__path = assert(opts.path, 'Missing path')
    return instance
end

--- Return path of directory on remote machine.
--- @return string
function M:path()
    return self.__path
end

--- Return canonicalized path of directory on remote machine.
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

--- Creates the directory and all of the parent components on the remote machine
--- @param opts? spec.e2e.IgnoreErrorsOpts
--- @return boolean
function M:make(opts)
    local results = self.__driver:exec('mkdir', { '-p', self.__path }, opts)
    return results.success
end

--- Lists directory contents as individual items
--- @param opts? spec.e2e.IgnoreErrorsOpts
--- @return string[]|nil
function M:items(opts)
    local results = self.__driver:exec('ls', { self.__path }, opts)
    if results.success then
        return vim.tbl_filter(function(item)
            return item ~= ''
        end, vim.split(results.output, '\n', { plain = true }))
    end
end

--- References a remote file within the directory; if no relative path is provided
--- then a random file path will be produced
---
--- @param rel_path? string Relative path within the remote directory
--- @return spec.e2e.RemoteFile
function M:file(rel_path)
    rel_path = rel_path or self.__driver:random_file_name()
    return self.__driver:remote_file(self.__path .. '/' .. rel_path)
end

--- References a remote directory within the directory; if no relative path is provided
--- then a random directory path will be produced
---
--- @param rel_path? string Relative path within the remote directory
--- @return spec.e2e.RemoteDir
function M:dir(rel_path)
    rel_path = rel_path or self.__driver:random_dir_name()
    return self.__driver:remote_dir(self.__path .. '/' .. rel_path)
end

--- References a remote symlink within the directory; if no relative path is provided
--- then a random symlink path will be produced
---
--- @param rel_path? string Relative path within the remote directory
--- @return spec.e2e.RemoteSymlink
function M:symlink(rel_path)
    rel_path = rel_path or self.__driver:random_dir_name()
    return self.__driver:remote_symlink(self.__path .. '/' .. rel_path)
end

--- Checks if dir's path exists and is a directory.
--- @param opts? spec.e2e.IgnoreErrorsOpts
--- @return boolean
function M:exists(opts)
    local cmd = 'test -d ' .. self.__path .. ' && echo yes || echo no'
    local results = self.__driver:exec('sh', { '-c', '"' .. cmd .. '"' }, opts)
    return vim.trim(results.output) == 'yes'
end

--- Removes the remote directory at the specified path along with any items within.
--- @param opts? spec.e2e.IgnoreErrorsOpts
--- @return boolean
function M:remove(opts)
    local results = self.__driver:exec('rm', { '-rf', self.__path }, opts)
    return results.success
end

return M
