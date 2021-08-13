local c = require('spec.e2e.config')
local editor = require('distant.editor')
local s = require('distant.internal.state')

local Driver = {}
Driver.__index = Driver

-------------------------------------------------------------------------------
-- DRIVER SETUP & TEARDOWN
-------------------------------------------------------------------------------

--- Initializes a driver for e2e tests
function Driver:setup(timeout, interval)
    timeout = timeout or c.timeout
    interval = interval or c.timeout_interval

    -- First, attempt to launch and connect to a remote session
    local args = {
        distant = c.bin,
        extra_server_args = '"--current-dir \"' .. c.root_dir .. '\" --shutdown-after 60"',
    }
    editor.launch(c.host, args)
    local status = vim.fn.wait(timeout, function() return s.session() ~= nil end, interval)
    assert(status == 0, 'Session not received in time')

    -- Create a new instance and assign the session to it
    local obj = {}
    setmetatable(obj, Driver)
    obj.__state = {
        session = s.session(),
        fixtures = {},
    }

    return obj
end

--- Tears down driver, cleaning up resources
function Driver:teardown()
    self.__state.session = nil

    for _, fixture in ipairs(self.__state.fixtures) do
        fixture.remove()
    end
end

-------------------------------------------------------------------------------
-- DRIVER FIXTURE OPERATIONS
-------------------------------------------------------------------------------

local function random_file_name(ext)
    assert(type(ext) == 'string', 'ext must be a string')
    local filename = 'test-file-' .. math.floor(math.random() * 10000)
    if type(ext) == 'string' and string.len(ext) > 0 then
        filename = filename .. '.' .. ext
    end
    return filename
end

--- Creates a new fixture using the provided arguments
---
--- * lines string[]|string: list of lines or a singular string containing contents
--- * ext string|nil: extension to use on the created file
---
--- @return string path The path on the remote machine to the fixture
function Driver:new_fixture(opts)
    assert(type(opts) == 'table', 'opts must be a table')
    assert(
        type(opts.lines) == 'string' or vim.tbl_islist(opts.lines),
        'opts.lines invalid'
    )

    -- Define our file path
    local path = '/tmp/' .. random_file_name(opts.ext)

    -- Ensure our contents for the fixture is a string
    local contents = opts.lines
    if vim.tbl_islist(contents) then
        contents = table.concat(contents, '\n')
    end

    -- Create the remote file
    local rf = self.remote_file(path)
    rf.write(contents)

    -- Store our new fixture in fixtures list
    table.insert(self.__state.fixtures, rf)

    -- Also return the fixture
    return rf
end

-------------------------------------------------------------------------------
-- DRIVER BUFFER OPERATIONS
-------------------------------------------------------------------------------

Driver.buffer = function(buf)
    buf = buf or vim.api.nvim_get_current_buf()

    local obj = {}

    --- Returns buffer id
    obj.id = function()
        return buf
    end

    --- Return name of buffer
    obj.name = function()
        return vim.api.nvim_buf_get_name(buf)
    end

    --- Return filetype of buffer
    obj.filetype = function()
        return vim.api.nvim_buf_get_option(buf, 'filetype')
    end

    --- Return buftype of buffer
    obj.buftype = function()
        return vim.api.nvim_buf_get_option(buf, 'buftype')
    end

    --- Return buffer variable with given name
    obj.get_var = function(name)
        return vim.api.nvim_buf_get_var(buf, name)
    end

    --- Read lines from buffer
    obj.lines = function()
        return vim.api.nvim_buf_get_lines(
            buf,
            0,
            vim.api.nvim_buf_line_count(buf),
            true
        )
    end

    --- Set lines of buffer
    obj.set_lines = function(lines)
        vim.api.nvim_buf_set_lines(
            buf,
            0,
            vim.api.nvim_buf_line_count(buf),
            true,
            lines
        )
    end

    obj.assert = {}

    --- Asserts that the provided lines match the buffer
    obj.assert.same = function(lines)
        if type(lines) == 'string' then
            lines = vim.split(lines, '\n', true)
        end

        assert.are.same(lines, obj.lines())
    end

    return obj
end

-------------------------------------------------------------------------------
-- DRIVER REMOTE FILE OPERATIONS
-------------------------------------------------------------------------------

Driver.remote_file = function(remote_path)
    assert(type(remote_path) == 'string', 'remote_path must be a string')

    local obj = {}

    --- Return path of file on remote machine
    --- @return string
    obj.path = function()
        return remote_path
    end

    --- Read remote file into list of lines
    --- @return string[]
    obj.lines = function()
        local contents = obj.read()

        if contents then
            return vim.split(contents, '\n', true)
        end
    end

    --- Leverages scp and a temporary file to read a remote file into memory
    --- @return string
    obj.read = function()
        local path = os.tmpname()

        -- Copy the file locally
        local out = vim.fn.system({'scp', '-P', c.port, c.host .. ':' .. remote_path, path})
        local errno = tonumber(vim.v.shell_error)
        assert(errno == 0, 'scp failed (' .. errno .. '): ' .. out)

        -- Read the file into a string
        local contents = Driver.local_file(path).read()
        os.remove(path)
        return contents
    end

    --- Leverages scp and a temporary file to write a remote file from some string
    --- @param contents string
    --- @return boolean
    obj.write = function(contents)
        local path = os.tmpname()
        Driver.local_file(path).write(contents)

        -- Copy the file locally
        local out = vim.fn.system({'scp', '-P', c.port, path, c.host .. ':' .. remote_path})
        local errno = tonumber(vim.v.shell_error)
        os.remove(path)
        assert(errno == 0, 'scp failed (' .. errno .. '): ' .. out)
        return true
    end

    --- Leverages scp and a temporary file to write a remote file from a buffer
    --- @param buf number
    --- @return boolean
    obj.write_buf = function(buf)
        local contents = Driver.buffer(buf).lines()
        return obj.write(contents)
    end

    --- Removes the remote file at the specified path
    obj.remove = function()
        local out = vim.fn.system({'ssh', '-p', c.port, c.host, 'rm', '-f', remote_path})
        local errno = tonumber(vim.v.shell_error)
        assert(errno == 0, 'ssh rm failed (' .. errno .. '): ' .. out)
    end

    obj.assert = {}

    --- Asserts that the provided lines match the remote file
    obj.assert.same = function(lines)
        if type(lines) == 'string' then
            lines = vim.split(lines, '\n', true)
        end

        assert.are.same(lines, obj.lines())
    end

    return obj
end

-------------------------------------------------------------------------------
-- DRIVER LOCAL FILE OPERATIONS
-------------------------------------------------------------------------------

Driver.local_file = function(path)
    assert(type(path) == 'string', 'path must be a string')

    local obj = {}

    --- Return path of file on local machine
    --- @return string
    obj.path = function()
        return path
    end

    --- Read local file into list of lines
    --- @return string[]
    obj.lines = function()
        local contents = obj.read()

        if contents then
            return vim.split(contents, '\n', true)
        end
    end

    --- Read local file into string
    --- @return string
    obj.read = function()
        -- Read the file into a string
        local f = io.open(path, 'rb')
        assert(f, 'Failed to open ' .. path)

        local contents = f:read(_VERSION <= 'Lua 5.2' and '*a' or 'a')
        f:close()
        if type(contents) == 'string' then
            return contents
        end
    end

    --- Writes local file with contents
    --- @param contents string
    obj.write = function(contents)
        if vim.tbl_islist(contents) then
            contents = table.concat(contents, '\n')
        end

        local f = io.open(path, 'w')
        assert(f, 'Failed to open ' .. path)
        f:write(contents)
        f:flush()
        f:close()
    end

    obj.assert = {}

    --- Asserts that the provided lines match the file
    obj.assert.same = function(lines)
        if type(lines) == 'string' then
            lines = vim.split(lines, '\n', true)
        end

        assert.are.same(lines, obj.lines())
    end

    return obj
end

return Driver
