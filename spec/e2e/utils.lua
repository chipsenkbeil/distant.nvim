local c = require('spec.e2e.config')
local editor = require('distant.editor')
local s = require('distant.internal.state')

local utils = {}

-- Prints out the current test configuration
utils.print_config = function()
    print(vim.inspect(c))
end

-- Establishes a new session by launching; this will fail if ssh is not passwordless
utils.setup_session = function(timeout, interval)
    -- Create some additional arguments to pass
    local args = {
        distant = c.bin,
        extra_server_args = '"--current-dir \"' .. c.root_dir .. '\" --shutdown-after 60"',
    }

    editor.launch(c.host, args)
    return utils.wait_for_session(timeout, interval)
end

-- Waits for a session become available
utils.wait_for_session = function(timeout, interval)
    timeout = timeout or c.timeout
    interval = interval or c.timeout_interval

    local status = vim.fn.wait(timeout, function() return s.session() ~= nil end, interval)
    assert(status == 0, 'Session not received in time')
    return s.session()
end

--- Leverages scp and a temporary file to read a remote file into memory
--- @param remote_path string
--- @return string
utils.read_remote_file = function(remote_path)
    local path = os.tmpname()

    -- Copy the file locally
    local out = vim.fn.system({'scp', '-P', c.port, c.host .. ':' .. remote_path, path})
    local errno = tonumber(vim.v.shell_error)
    assert(errno == 0, 'scp failed (' .. errno .. '): ' .. out)

    -- Read the file into a string
    local contents = utils.read_local_file(path)
    os.remove(path)
    return contents
end

--- Read local file into string
--- @param path string
--- @return string
utils.read_local_file = function(path)
    -- Read the file into a string
    local f = io.open(path, 'rb')
    assert(f, 'Failed to open ' .. path)

    local contents = f:read(_VERSION <= 'Lua 5.2' and '*a' or 'a')
    f:close()
    if type(contents) == 'string' then
        return contents
    end
end

--- Leverages scp and a temporary file to write a remote file from some string
--- @param remote_path string
--- @param contents string
--- @return boolean
utils.write_remote_file = function(remote_path, contents)
    local path = os.tmpname()
    utils.write_local_file(path, contents)

    -- Copy the file locally
    local out = vim.fn.system({'scp', '-P', c.port, path, c.host .. ':' .. remote_path})
    local errno = tonumber(vim.v.shell_error)
    os.remove(path)
    assert(errno == 0, 'scp failed (' .. errno .. '): ' .. out)
    return true
end

--- Writes local file with contents
--- @param path string
--- @param contents string
utils.write_local_file = function(path, contents)
    local f = io.open(path, 'w')
    assert(f, 'Failed to open ' .. path)
    f:write(contents)
    f:flush()
    f:close()
end

--- Leverages scp and a temporary file to write a remote file from a buffer
--- @param remote_path string
--- @param buf number
--- @return boolean
utils.write_buf_to_remote_file = function(remote_path, buf)
    local contents = vim.fn.getbufline(buf, 1, '$')
    return utils.write_remote_file(remote_path, contents)
end

return utils
