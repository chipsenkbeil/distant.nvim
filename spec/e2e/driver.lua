local config = require('spec.e2e.config')
local editor = require('distant.editor')
local state = require('distant.state')
local settings = require('distant.settings')

local Driver = {}
Driver.__index = Driver

--- Maximum random value (inclusive) in form of [1, MAX_RAND_VALUE]
local MAX_RAND_VALUE = 100000
local seed = nil

local function next_id()
    --- Seed driver's random with time
    if seed == nil then
        seed = os.time() - os.clock() * 1000
        math.randomseed(seed)
    end

    return math.random(MAX_RAND_VALUE)
end

-------------------------------------------------------------------------------
-- DRIVER SETUP & TEARDOWN
-------------------------------------------------------------------------------

local session = nil

--- Initialize a session if one has not been initialized yet
local function initialize_session(timeout, interval)
    if session ~= nil then
        return session
    end

    timeout = timeout or config.timeout
    interval = interval or config.timeout_interval

    -- Attempt to launch and connect to a remote session
    -- NOTE: We bump up our port range as tests are run in parallel and each
    --       stand up a new distant connection AND server, meaning we need
    --       to avoid running out of ports!
    -- TODO: Because of the above situation, should we instead have drivers use
    --       the same connection and only have one perform an actual launch?
    editor.launch({
        host = config.host,
        distant_bin = config.bin,
        distant_args = {'--current-dir', config.root_dir, '--shutdown-after', '60', '--port', '8080:8999'},
    })
    local status = vim.fn.wait(timeout, function() return state.session ~= nil end, interval)

    -- Validate that we were successful
    assert(status == 0, 'Session not received in time')
    return state.session
end

--- Initializes a driver for e2e tests
function Driver:setup(opts)
    opts = opts or {}

    if type(opts.settings) == 'table' then
        settings.merge(opts.settings)
    end

    -- Create a new instance and assign the session to it
    local obj = {}
    setmetatable(obj, Driver)
    obj.__state = {
        session = nil,
        fixtures = {},
    }

    if not opts.lazy then
        obj:initialize(opts)
    end

    return obj
end

--- Initializes the session of the driver
function Driver:initialize(opts)
    opts = opts or {}

    if type(opts.settings) == 'table' then
        settings.merge(opts.settings)
    end

    self.__state.session = initialize_session(opts.timeout, opts.interval)
    return self
end

--- Tears down driver, cleaning up resources
function Driver:teardown()
    self.__state.session = nil

    for _, fixture in ipairs(self.__state.fixtures) do
        fixture.remove({ignore_errors = true})
    end
end

-------------------------------------------------------------------------------
-- DRIVER EXECUTABLE FUNCTIONS
-------------------------------------------------------------------------------

--- Executes a program on the remote machine
--- @return string|nil
Driver.exec = function(cmd, args, opts)
    args = args or {}
    opts = opts or {}

    local out = vim.fn.system({'ssh', '-p', config.port, config.host, cmd, unpack(args)})
    local errno = tonumber(vim.v.shell_error)

    local success = errno == 0
    if not opts.ignore_errors then
        assert(success, 'ssh ' .. cmd .. ' failed (' .. errno .. '): ' .. out)
    end
    if success then
        return out
    end
end

-------------------------------------------------------------------------------
-- DRIVER FIXTURE OPERATIONS
-------------------------------------------------------------------------------

local function random_file_name(ext)
    local filename = 'test_file_' .. next_id()
    if type(ext) == 'string' and string.len(ext) > 0 then
        filename = filename .. '.' .. ext
    end
    return filename
end

local function random_dir_name()
    return 'test_dir_' .. next_id()
end

local function random_symlink_name()
    return 'test_symlink_' .. next_id()
end

--- Creates a new fixture for a file using the provided arguments
---
--- * base_path string|nil: base directory in which to create a fixture
--- * lines string[]|string: list of lines or a singular string containing contents
--- * ext string|nil: extension to use on the created file
---
--- @return table fixture The new file fixture (remote_file)
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
    assert(rf.write(contents), 'Failed to populate file fixture: ' .. path)

    -- Store our new fixture in fixtures list
    table.insert(self.__state.fixtures, rf)

    -- Also return the fixture
    return rf
end

--- Creates a new fixture for a directory using the provided arguments
---
--- * base_path string|nil: base directory in which to create a fixture
--- * items string[]|nil: items to create within directory
---
--- @return table fixture The new directory fixture (remote_dir)
function Driver:new_dir_fixture(opts)
    opts = opts or {}
    assert(type(opts) == 'table', 'opts must be a table')
    local base_path = opts.base_path or '/tmp'
    local path = base_path .. '/' .. random_dir_name()

    -- Create the remote directory
    local rd = Driver.remote_dir(path)
    assert(rd.make(), 'Failed to create directory fixture: ' .. rd.path())

    -- Store our new fixture in fixtures list
    table.insert(self.__state.fixtures, rd)

    -- Create all additional items within fixture
    local items = opts.items or {}
    for _, item in ipairs(items) do
        if type(item) == 'string' then
            local is_dir = vim.endswith(item, '/')
            if is_dir then
                local dir = rd.dir(item)
                assert(dir.make(), 'Failed to create dir: ' .. dir.path())
            else
                local file = rd.file(item)
                assert(file.touch(), 'Failed to create file: ' .. file.path())
            end
        elseif vim.tbl_islist(item) and #item == 2 then
            local symlink = rd.symlink(item[1])
            local target = rd.file(item[2]).path()
            assert(symlink.make(target), 'Failed to create symlink: ' .. symlink.path() .. ' to ' .. target)
        end
    end

    return rd
end

--- Creates a new fixture for a symlink using the provided arguments
---
--- * base_path string|nil: base directory in which to create a fixture
--- * source string: path to source that will be linked to
---
--- @return table fixture The new symlink fixture (remote_symlink)
function Driver:new_symlink_fixture(opts)
    opts = opts or {}
    assert(type(opts) == 'table', 'opts must be a table')
    assert(type(opts.source) == 'string', 'opts.source must be a string')
    local base_path = opts.base_path or '/tmp'
    local path = base_path .. '/' .. random_symlink_name()

    -- Create the remote symlink
    local rl = Driver.remote_symlink(path)
    assert(rl.make(opts.source), 'Failed to create symlink: ' .. rl.path())

    -- Store our new fixture in fixtures list
    table.insert(self.__state.fixtures, rl)

    return rl
end

-------------------------------------------------------------------------------
-- DRIVER WINDOW OPERATIONS
-------------------------------------------------------------------------------

--- @return table window
Driver.window = function(win)
    win = win or vim.api.nvim_get_current_win()

    local obj = {}

    --- Returns window id
    --- @return number
    obj.id = function()
        return win
    end

    --- Returns id of buffer attached to window
    --- @return number
    obj.buf = function()
        return vim.api.nvim_win_get_buf(win)
    end

    --- Places the specific buffer in this window
    --- @param buf number
    obj.set_buf = function(buf)
        vim.api.nvim_win_set_buf(win, buf)
    end

    --- Moves the cursor to the current line in the window
    --- @param line number (1-based index)
    obj.move_cursor_to_line = function(line)
        assert(line ~= 0, 'line is 1-based index')
        vim.api.nvim_win_set_cursor(win, {line, 0})
    end

    --- Moves cursor to line and column where first match is found
    --- for the given pattern
    --- @param p string pattern to match against
    --- @param line_only? boolean if true, will only move to the line and not column
    --- @return number line, number col The line and column position, or nil if no movement
    obj.move_cursor_to = function(p, line_only)
        assert(type(p) == 'string', 'pattern must be a string')
        local lines = Driver.buffer(obj.buf()).lines()

        for ln, line in ipairs(lines) do
            local start = string.find(line, p)
            if start ~= nil then
                local col = start - 1
                if line_only then
                    col = 0
                end

                vim.api.nvim_win_set_cursor(win, {ln, col})
                return ln, col
            end
        end
    end

    --- Returns the line number (1-based index) of the cursor's position
    --- @return number line (1-based index)
    obj.cursor_line_number = function()
        return vim.api.nvim_win_get_cursor(win)[1]
    end

    --- Retrieves content at line where cursor is
    --- @return string
    obj.line_at_cursor = function()
        local ln = obj.cursor_line_number() - 1
        return vim.api.nvim_buf_get_lines(
            obj.buf(),
            ln,
            ln + 1,
            true
        )[1]
    end

    return obj
end

-------------------------------------------------------------------------------
-- DRIVER BUFFER OPERATIONS
-------------------------------------------------------------------------------

--- @return table buffer
Driver.make_buffer = function(contents, opts)
    opts = opts or {}
    local buf = vim.api.nvim_create_buf(true, false)
    assert(buf ~= 0, 'failed to create buffer')

    local buffer = Driver.buffer(buf)

    local lines = contents
    if type(lines) == 'string' then
        lines = vim.split(lines, '\n', true)
    else
        lines = {}
    end

    buffer.set_lines(lines, opts)

    return buffer
end

--- @return table buffer
Driver.buffer = function(buf)
    buf = buf or vim.api.nvim_get_current_buf()

    local obj = {}

    --- Returns buffer id
    --- @return number
    obj.id = function()
        return buf
    end

    --- Return name of buffer
    --- @return string
    obj.name = function()
        return vim.api.nvim_buf_get_name(buf)
    end

    --- Return filetype of buffer
    --- @return string
    obj.filetype = function()
        return vim.api.nvim_buf_get_option(buf, 'filetype')
    end

    --- Return buftype of buffer
    --- @return string
    obj.buftype = function()
        return vim.api.nvim_buf_get_option(buf, 'buftype')
    end

    --- Return if modifiable
    --- @return boolean
    obj.modifiable = function()
        return vim.api.nvim_buf_get_option(buf, 'modifiable')
    end

    --- Return buffer variable with given name
    --- @return any
    obj.get_var = function(name)
        return vim.api.nvim_buf_get_var(buf, name)
    end

    --- Return the remote path associated with the buffer, if it has one
    --- @return string|nil
    obj.remote_path = function()
        local success, data = pcall(obj.get_var, 'distant_remote_path')
        if success then
            return data
        end
    end

    --- Return the remote type associated with the buffer, if it has one
    --- @return string|nil
    obj.remote_type = function()
        local success, data = pcall(obj.get_var, 'distant_remote_type')
        if success then
            return data
        end
    end

    --- Reads lines from buffer as a single string separated by newlines
    --- @return string
    obj.contents = function()
        return table.concat(obj.lines(), '\n')
    end

    --- Read lines from buffer
    --- @return string[]
    obj.lines = function()
        return vim.api.nvim_buf_get_lines(
            buf,
            0,
            vim.api.nvim_buf_line_count(buf),
            true
        )
    end

    --- Set lines of buffer
    --- @param lines string[]
    --- @param opts table
    obj.set_lines = function(lines, opts)
        opts = opts or {}

        vim.api.nvim_buf_set_lines(
            buf,
            0,
            vim.api.nvim_buf_line_count(buf),
            true,
            lines
        )

        if opts.modified ~= nil then
            vim.api.nvim_buf_set_option(buf, 'modified', opts.modified)
        end
    end

    --- Return if buffer is focused
    --- @return boolean
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

--- @return table remote_dir
Driver.remote_dir = function(remote_path)
    assert(type(remote_path) == 'string', 'remote_path must be a string')

    local obj = {}

    --- Return path of directory on remote machine
    --- @return string
    obj.path = function()
        return remote_path
    end

    --- Return canonicalized path of directory on remote machine
    --- @param opts? table
    --- @return string|nil
    obj.canonicalized_path = function(opts)
        opts = opts or {}
        local out = vim.fn.system({'ssh', '-p', config.port, config.host, 'realpath', remote_path})
        local errno = tonumber(vim.v.shell_error)
        local success = errno == 0
        if not opts.ignore_errors then
            assert(success, 'ssh realpath failed (' .. errno .. '): ' .. out)
        end
        if success then
            return vim.trim(out)
        end
    end

    --- Creates the directory and all of the parent components on the remote machine
    --- @param opts? table
    --- @return boolean
    obj.make = function(opts)
        opts = opts or {}
        local out = vim.fn.system({'ssh', '-p', config.port, config.host, 'mkdir', '-p', remote_path})
        local errno = tonumber(vim.v.shell_error)

        local success = errno == 0
        if not opts.ignore_errors then
            assert(success, 'ssh mkdir failed (' .. errno .. '): ' .. out)
        end
        return success
    end

    --- Lists directory contents as individual items
    --- @param opts? table
    --- @return string[]|nil
    obj.items = function(opts)
        opts = opts or {}
        local out = vim.fn.system({'ssh', '-p', config.port, config.host, 'ls', remote_path})
        local errno = tonumber(vim.v.shell_error)
        local success = errno == 0
        if not opts.ignore_errors then
            assert(success, 'ssh ls failed (' .. errno .. '): ' .. out)
        end
        if success then
            return vim.tbl_filter(function(item)
                return item ~= ''
            end, vim.split(out, '\n', true))
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

    --- References a remote symlink within the directory; if no relative path is provided
    --- then a random symlink path will be produced
    ---
    --- @param rel_path? string Relative path within the remote directory
    --- @return table
    obj.symlink = function(rel_path)
        rel_path = rel_path or random_dir_name()
        return Driver.remote_symlink(remote_path .. '/' .. rel_path)
    end

    --- Checks if dir's path exists and is a directory
    --- @param opts? table
    --- @return boolean
    obj.exists = function(opts)
        opts = opts or {}

        local cmd = 'test -d ' .. remote_path .. ' && echo yes || echo no'
        local out = vim.fn.system({'ssh', '-p', config.port, config.host, 'sh', '-c', '"' .. cmd .. '"'})
        local errno = tonumber(vim.v.shell_error)

        local success = errno == 0
        if not opts.ignore_errors then
            assert(success, 'ssh test failed (' .. errno .. '): ' .. out)
        end
        return vim.trim(out) == 'yes'
    end

    --- Removes the remote directory at the specified path along with any items within
    --- @param opts? table
    --- @return boolean
    obj.remove = function(opts)
        opts = opts or {}
        local out = vim.fn.system({'ssh', '-p', config.port, config.host, 'rm', '-rf', remote_path})
        local errno = tonumber(vim.v.shell_error)

        local success = errno == 0
        if not opts.ignore_errors then
            assert(success, 'ssh rm failed (' .. errno .. '): ' .. out)
        end
        return success
    end

    return obj
end

-------------------------------------------------------------------------------
-- DRIVER REMOTE FILE OPERATIONS
-------------------------------------------------------------------------------

--- @return table remote_file
Driver.remote_file = function(remote_path)
    assert(type(remote_path) == 'string', 'remote_path must be a string')

    local obj = {}

    --- Return path of file on remote machine
    --- @return string
    obj.path = function()
        return remote_path
    end

    --- Return canonicalized path of file on remote machine
    --- @param opts? table
    --- @return string|nil
    obj.canonicalized_path = function(opts)
        opts = opts or {}
        local out = vim.fn.system({'ssh', '-p', config.port, config.host, 'realpath', remote_path})
        local errno = tonumber(vim.v.shell_error)
        local success = errno == 0
        if not opts.ignore_errors then
            assert(success, 'ssh realpath failed (' .. errno .. '): ' .. out)
        end
        if success then
            return vim.trim(out)
        end
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
    --- @return string|nil
    obj.read = function(opts)
        opts = opts or {}

        local path = os.tmpname()

        -- Copy the file locally
        local out = vim.fn.system({'scp', '-P', config.port, config.host .. ':' .. remote_path, path})
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
        local out = vim.fn.system({'scp', '-P', config.port, path, config.host .. ':' .. remote_path})
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

        local out = vim.fn.system({'ssh', '-p', config.port, config.host, 'touch', remote_path})
        local errno = tonumber(vim.v.shell_error)

        local success = errno == 0
        if not opts.ignore_errors then
            assert(success, 'ssh touch failed (' .. errno .. '): ' .. out)
        end
        return success
    end

    --- Checks if file's path exists and is a regular file
    --- @param opts? table
    --- @return boolean
    obj.exists = function(opts)
        opts = opts or {}

        local cmd = 'test -f ' .. remote_path .. ' && echo yes || echo no'
        local out = vim.fn.system({'ssh', '-p', config.port, config.host, 'sh', '-c', '"' .. cmd .. '"'})
        local errno = tonumber(vim.v.shell_error)

        local success = errno == 0
        if not opts.ignore_errors then
            assert(success, 'ssh test failed (' .. errno .. '): ' .. out)
        end
        return vim.trim(out) == 'yes'
    end

    --- Removes the remote file at the specified path
    --- @param opts? table
    --- @return boolean
    obj.remove = function(opts)
        opts = opts or {}

        local out = vim.fn.system({'ssh', '-p', config.port, config.host, 'rm', '-f', remote_path})
        local errno = tonumber(vim.v.shell_error)

        local success = errno == 0
        if not opts.ignore_errors then
            assert(success, 'ssh rm failed (' .. errno .. '): ' .. out)
        end
        return success
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
-- DRIVER REMOTE SYMLINK OPERATIONS
-------------------------------------------------------------------------------

--- @return table remote_symlink
Driver.remote_symlink = function(remote_path)
    assert(type(remote_path) == 'string', 'remote_path must be a string')

    local obj = {}

    --- Return path of symlink on remote machine
    --- @return string
    obj.path = function()
        return remote_path
    end

    --- Return canonicalized path of symlink on remote machine
    --- @param opts? table
    --- @return string|nil
    obj.canonicalized_path = function(opts)
        opts = opts or {}
        local out = vim.fn.system({'ssh', '-p', config.port, config.host, 'realpath', remote_path})
        local errno = tonumber(vim.v.shell_error)
        local success = errno == 0
        if not opts.ignore_errors then
            assert(success, 'ssh realpath failed (' .. errno .. '): ' .. out)
        end
        if success then
            return vim.trim(out)
        end
    end

    --- Return path of source of symlink, if it exists
    --- @param opts? table
    --- @return string|nil
    obj.source_path = function(opts)
        opts = opts or {}

        local out = vim.fn.system({'ssh', '-p', config.port, config.host, 'readlink', remote_path})
        local errno = tonumber(vim.v.shell_error)

        local success = errno == 0
        if not opts.ignore_errors then
            assert(success, 'ssh test failed (' .. errno .. '): ' .. out)
        end
        if success then
            return vim.trim(out)
        end
    end

    --- Creates the symlink, pointing to the specified location
    --- @param source string Path that is the source for a symlink (what it points to)
    --- @param opts? table
    --- @return boolean
    obj.make = function(source, opts)
        opts = opts or {}
        local out = vim.fn.system({'ssh', '-p', config.port, config.host, 'ln', '-s', source, remote_path})
        local errno = tonumber(vim.v.shell_error)

        local success = errno == 0
        if not opts.ignore_errors then
            assert(success, 'ssh mkdir failed (' .. errno .. '): ' .. out)
        end
        return success
    end

    --- Checks if path exists and is a symlink
    --- @param opts? table
    --- @return boolean
    obj.exists = function(opts)
        opts = opts or {}

        local cmd = 'test -L ' .. remote_path .. ' && echo yes || echo no'
        local out = vim.fn.system({'ssh', '-p', config.port, config.host, 'sh', '-c', '"' .. cmd .. '"'})
        local errno = tonumber(vim.v.shell_error)

        local success = errno == 0
        if not opts.ignore_errors then
            assert(success, 'ssh test failed (' .. errno .. '): ' .. out)
        end
        return vim.trim(out) == 'yes'
    end

    --- Removes the remote symlink at the specified path
    --- @param opts? table
    --- @return boolean
    obj.remove = function(opts)
        opts = opts or {}

        local out = vim.fn.system({'ssh', '-p', config.port, config.host, 'rm', '-f', remote_path})
        local errno = tonumber(vim.v.shell_error)

        local success = errno == 0
        if not opts.ignore_errors then
            assert(success, 'ssh rm failed (' .. errno .. '): ' .. out)
        end
        return success
    end

    return obj
end

-------------------------------------------------------------------------------
-- DRIVER LOCAL FILE OPERATIONS
-------------------------------------------------------------------------------

--- @return table local_file
Driver.local_file = function(path)
    assert(type(path) == 'string', 'path must be a string')

    local obj = {}

    --- Return path of file on local machine
    --- @return string
    obj.path = function()
        return path
    end

    --- Return canonicalized path of file on local machine
    --- @return string|nil
    obj.canonicalized_path = function()
        return vim.loop.fs_realpath(path)
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
