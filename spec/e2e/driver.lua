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
        fixture.remove({ignore_errors = true})
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

local function random_dir_name()
    return 'test_dir_' .. math.floor(math.random() * 10000)
end

--- Creates a new fixture for a file using the provided arguments
---
--- * base_path string|nil: base directory in which to create a fixture
--- * lines string[]|string: list of lines or a singular string containing contents
--- * ext string|nil: extension to use on the created file
---
--- @return string path The path on the remote machine to the fixture
function Driver:new_file_fixture(opts)
    opts = opts or {}
    assert(type(opts) == 'table', 'opts must be a table')
    assert(
        type(opts.lines) == 'string' or vim.tbl_islist(opts.lines),
        'opts.lines invalid or missing'
    )

    local base_path = opts.base_path or '/tmp'

    -- Define our file path
    local path = base_path .. '/' .. random_file_name(opts.ext)

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

--- Creates a new fixture for a directory using the provided arguments
---
--- * base_path string|nil: base directory in which to create a fixture
---
--- @return string path The path on the remote machine to the fixture
function Driver:new_dir_fixture(opts)
    opts = opts or {}
    assert(type(opts) == 'table', 'opts must be a table')
    local base_path = opts.base_path or '/tmp'
    local path = base_path .. '/' .. random_dir_name()

    -- Create the remote directory
    local rd = Driver.remote_dir(path)
    rd.make()

    -- Store our new fixture in fixtures list
    table.insert(self.__state.fixtures, rd)

    return rd
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

    --- Return if modifiable
    obj.modifiable = function()
        return vim.api.nvim_buf_get_option(buf, 'modifiable')
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

    --- Return if buffer is focused
    obj.is_focused = function()
        return buf == vim.api.nvim_get_current_buf()
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
-- DRIVER REMOTE DIRECTORY OPERATIONS
-------------------------------------------------------------------------------

Driver.remote_dir = function(remote_path)
    assert(type(remote_path) == 'string', 'remote_path must be a string')

    local obj = {}

    --- Return path of directory on remote machine
    --- @return string
    obj.path = function()
        return remote_path
    end

    --- Creates the directory and all of the parent components on the remote machine
    --- @param opts? table
    obj.make = function(opts)
        opts = opts or {}
        local out = vim.fn.system({'ssh', '-p', c.port, c.host, 'mkdir', '-p', remote_path})
        local errno = tonumber(vim.v.shell_error)
        if not opts.ignore_errors then
            assert(errno == 0, 'ssh mkdir failed (' .. errno .. '): ' .. out)
        end
    end

    --- Lists directory contents as individual items
    --- @param opts? table
    --- @return string[]
    obj.items = function(opts)
        opts = opts or {}
        local out = vim.fn.system({'ssh', '-p', c.port, c.host, 'ls', remote_path})
        local errno = tonumber(vim.v.shell_error)
        local success = errno == 0
        if not opts.ignore_errors then
            assert(success, 'ssh ls failed (' .. errno .. '): ' .. out)
        end
        if success then
            return vim.split(out, '\n', true)
        end
    end

    --- References a remote file within the directory; if no relative path is provided
    --- then a random file path will be produced
    ---
    --- @param rel_path? string Relative path within the remote directory
    --- @return table
    obj.file = function(rel_path)
        rel_path = rel_path or random_file_name()
        return Driver.remote_file(remote_path .. '/' .. rel_path)
    end

    --- References a remote directory within the directory; if no relative path is provided
    --- then a random directory path will be produced
    ---
    --- @param rel_path? string Relative path within the remote directory
    --- @return table
    obj.dir = function(rel_path)
        rel_path = rel_path or random_dir_name()
        return Driver.remote_dir(remote_path .. '/' .. rel_path)
    end

    --- Removes the remote directory at the specified path along with any items within
    --- @param opts? table
    obj.remove = function(opts)
        opts = opts or {}
        local out = vim.fn.system({'ssh', '-p', c.port, c.host, 'rm', '-rf', remote_path})
        local errno = tonumber(vim.v.shell_error)
        if not opts.ignore_errors then
            assert(errno == 0, 'ssh rm failed (' .. errno .. '): ' .. out)
        end
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
    --- @param opts? table
    --- @return string[]
    obj.lines = function(opts)
        local contents = obj.read(opts)

        if contents then
            return vim.split(contents, '\n', true)
        end
    end

    --- Leverages scp and a temporary file to read a remote file into memory
    --- @param opts? table
    --- @return string
    obj.read = function(opts)
        opts = opts or {}

        local path = os.tmpname()

        -- Copy the file locally
        local out = vim.fn.system({'scp', '-P', c.port, c.host .. ':' .. remote_path, path})
        local errno = tonumber(vim.v.shell_error)
        local success = errno == 0
        if not opts.ignore_errors then
            assert(success, 'scp failed (' .. errno .. '): ' .. out)
        end

        if success then
            -- Read the file into a string
            local contents = Driver.local_file(path).read()
            os.remove(path)
            return contents
        end
    end

    --- Leverages scp and a temporary file to write a remote file from some string
    --- @param contents string
    --- @param opts? table
    --- @return boolean
    obj.write = function(contents, opts)
        opts = opts or {}

        local path = os.tmpname()
        Driver.local_file(path).write(contents)

        -- Copy the file locally
        local out = vim.fn.system({'scp', '-P', c.port, path, c.host .. ':' .. remote_path})
        local errno = tonumber(vim.v.shell_error)
        os.remove(path)

        local success = errno == 0
        if not opts.ignore_errors then
            assert(success, 'scp failed (' .. errno .. '): ' .. out)
        end
        return success
    end

    --- Leverages scp and a temporary file to write a remote file from a buffer
    --- @param buf number
    --- @param opts? table
    --- @return boolean
    obj.write_buf = function(buf, opts)
        local contents = Driver.buffer(buf).lines()
        return obj.write(contents, opts)
    end

    --- Touches a remote file
    --- @param opts? table
    --- @return boolean
    obj.touch = function(opts)
        opts = opts or {}

        local out = vim.fn.system({'ssh', '-p', c.port, c.host, 'touch', remote_path})
        local errno = tonumber(vim.v.shell_error)

        if not opts.ignore_errors then
            assert(errno == 0, 'ssh touch failed (' .. errno .. '): ' .. out)
        end
    end

    --- Removes the remote file at the specified path
    --- @param opts? table
    obj.remove = function(opts)
        opts = opts or {}

        local out = vim.fn.system({'ssh', '-p', c.port, c.host, 'rm', '-f', remote_path})
        local errno = tonumber(vim.v.shell_error)

        if not opts.ignore_errors then
            assert(errno == 0, 'ssh rm failed (' .. errno .. '): ' .. out)
        end
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
    --- @param opts? table
    --- @return string[]
    obj.lines = function(opts)
        local contents = obj.read(opts)

        if contents then
            return vim.split(contents, '\n', true)
        end
    end

    --- Read local file into string
    --- @param opts? table
    --- @return string
    obj.read = function(opts)
        opts = opts or {}

        -- Read the file into a string
        local f = io.open(path, 'rb')
        if not opts.ignore_errors then
            assert(f, 'Failed to open ' .. path)
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
    --- @param opts? table
    --- @param contents string
    obj.write = function(contents, opts)
        opts = opts or {}

        if vim.tbl_islist(contents) then
            contents = table.concat(contents, '\n')
        end

        local f = io.open(path, 'w')
        if not opts.ignore_errors then
            assert(f, 'Failed to open ' .. path)
        end

        if f then
            f:write(contents)
            f:flush()
            f:close()
        end
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
