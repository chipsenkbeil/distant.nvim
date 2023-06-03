local make_assert = require('spec.e2e.driver.assert')

--- @class spec.e2e.RemoteFile
--- @field private __driver spec.e2e.Driver
--- @field private __path string #path on the remote machine
--- @field assert spec.e2e.Assert
local M = {}
M.__index = M

--- Creates a new instance of a reference to a remote file.
--- @param opts {driver:spec.e2e.Driver, path:string}
--- @return spec.e2e.RemoteFile
function M:new(opts)
    local instance = {}
    setmetatable(instance, M)
    instance.__driver = assert(opts.driver, 'Missing driver')
    instance.__path = assert(opts.path, 'Missing path')
    instance.assert = make_assert({
        get_lines = function() return M.lines(instance) or {} end
    })
    return instance
end

--- Return path of file on remote machine
--- @return string
function M:path()
    return self.__path
end

--- Return canonicalized path of file on remote machine
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

--- Read remote file into list of lines
--- @param opts? spec.e2e.IgnoreErrorsOpts
--- @return string[]|nil
function M:lines(opts)
    local contents = self:read(opts)

    if contents then
        return vim.split(contents, '\n', { plain = true })
    end
end

--- Leverages scp and a temporary file to read a remote file into memory
--- @param opts? spec.e2e.IgnoreErrorsOpts
--- @return string|nil
function M:read(opts)
    opts = opts or {}

    local path = os.tmpname()

    --- Copy remote file into local one
    local success = self.__driver:copy(
        self.__path,
        path,
        vim.tbl_extend('keep', { src = 'remote', dst = 'local' }, opts)
    )

    -- Read the file into a string
    if success then
        local contents = self.__driver:local_file(path):read()
        os.remove(path)
        return contents
    end
end

--- Leverages scp and a temporary file to write a remote file from some string
--- @param contents string|string[]
--- @param opts? spec.e2e.IgnoreErrorsOpts
--- @return boolean
function M:write(contents, opts)
    opts = opts or {}

    local path = os.tmpname()
    self.__driver:local_file(path):write(contents)

    --- Copy local file into remote one
    local success = self.__driver:copy(
        path,
        self.__path,
        vim.tbl_extend('keep', { src = 'local', dst = 'remote' }, opts)
    )

    os.remove(path)
    return success
end

--- Leverages scp and a temporary file to write a remote file from a buffer
--- @param buf number
--- @param opts? spec.e2e.IgnoreErrorsOpts
--- @return boolean
function M:write_buf(buf, opts)
    local contents = self.__driver:buffer(buf):lines()
    return self:write(contents, opts)
end

--- Touches a remote file
--- @param opts? spec.e2e.IgnoreErrorsOpts
--- @return boolean
function M:touch(opts)
    return self.__driver:exec('touch', { self.__path }, opts).success
end

--- Checks if file's path exists and is a regular file
--- @param opts? spec.e2e.IgnoreErrorsOpts
--- @return boolean
function M:exists(opts)
    local cmd = 'test -f ' .. self.__path .. ' && echo yes || echo no'
    local results = self.__driver:exec('sh', { '-c', '"' .. cmd .. '"' }, opts)
    return vim.trim(results.output) == 'yes'
end

--- Removes the remote file at the specified path
--- @param opts? spec.e2e.IgnoreErrorsOpts
--- @return boolean
function M:remove(opts)
    return self.__driver:exec('rm', { '-f', self.__path }, opts).success
end

return M
