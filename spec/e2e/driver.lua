local AuthHandler = require('distant-core').AuthHandler
local config = require('spec.e2e.config')
local Destination = require('distant-core').Destination
local editor = require('distant.editor')
local plugin = require('distant')
local utils = require('distant-core').utils

local Buffer = require('spec.e2e.driver.buffer')
local LocalFile = require('spec.e2e.driver.local_file')
local RemoteDir = require('spec.e2e.driver.remote_dir')
local RemoteFile = require('spec.e2e.driver.remote_file')
local RemoteSymlink = require('spec.e2e.driver.remote_symlink')
local Window = require('spec.e2e.driver.window')

--- Used to indicate how long the driver will wait to capture a response.
local CAPTURE_TIMEOUT = {
    MAX      = 5000,
    INTERVAL = 100,
}

--- @alias spec.e2e.Fixture
--- | spec.e2e.LocalFile
--- | spec.e2e.RemoteDir
--- | spec.e2e.RemoteFile
--- | spec.e2e.RemoteSymlink

--- @class spec.e2e.Driver
--- @field label string
--- @field tmp_dir string # path to tmp directory
--- @field private __log_level number
--- @field private __client? distant.core.Client #active client being used by this driver
--- @field private __fixtures spec.e2e.Fixture[] #fixtures managed by this driver
local M = {}
M.__index = M

--- Maximum time (in milliseconds) to wait for the driver to finish setting up
--- @type integer
local SETUP_TIMEOUT = 10 * 1000

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

--- @param cmd string
--- @param args string[]
--- @return string[]
local function ssh_cmd(cmd, args)
    return {
        'ssh',
        '-p', config.port,
        '-o', 'StrictHostKeyChecking=no',
        config.host, cmd,
        unpack(args)
    }
end

-------------------------------------------------------------------------------
-- DRIVER SETUP & TEARDOWN
-------------------------------------------------------------------------------

--- @type distant.core.Client|nil
local client = nil

--- Initialize a client if one has not been initialized yet
--- @param opts? {args?:string[], log_dir?:string, timeout?:number, interval?:number}
--- @return distant.core.Client
local function initialize_client(opts)
    opts = opts or {}
    if client ~= nil then
        return client
    end

    local log_file = string.format(
        '%s_log.txt',
        opts.log_dir
        and vim.fs.normalize(opts.log_dir) .. '/client'
        or vim.fn.tempname()
    )

    -- Print out our log location and flush to ensure that it shows up in case we get stuck
    print('Client logging initialized', log_file)
    io.stdout:flush()

    -- Update our launch options
    opts = {
        destination = Destination:new({
            scheme = 'ssh',
            host = config.host,
            port = config.port,
            username = config.user,
        }),
        auth = AuthHandler:dummy(),
        distant = {
            bin = config.bin,
            args = vim.list_extend({
                '--current-dir', config.root_dir,
                '--shutdown', 'lonely=5',
                '--port', '8080:8999',
                '--log-file', log_file,
                '--log-level', 'trace',
            }, opts.args or {})
        },
        timeout = opts.timeout,
        interval = opts.interval,
    }

    editor.launch(opts, function(err, c)
        if err then
            local desc = string.format('editor.launch(%s)', vim.inspect(opts))
            error(string.format(
                'For %s, failed: %s',
                desc, err
            ))
        else
            client = c
        end
    end)

    local _, status = vim.wait(opts.timeout or config.timeout, function()
        return client ~= nil
    end, opts.interval or config.timeout_interval)

    if client then
        return client
    end

    if status then
        error('Client not initialized in time (status == ' .. status .. ')')
    else
        error('Client not initialized in time (status == ???)')
    end
end

--- Initializes a driver for e2e tests.
---
--- ### Options
---
--- * `label` - used to distinguish this driver from others.
--- * `tmp_dir` - alternative temporary directory to use during tests.
--- * `debug` - if true, will enable debug printing.
--- * `lazy` - if true, will not initialize the driver (no client/manager).
---   Will need to invoke `Driver:initialize` in order to set up client & manager.
--- * `settings` - if provided, will merge with global settings.
---
--- @param opts {label:string, log_dir?:string, tmp_dir?:string, log?:number, lazy?:boolean, no_client?:boolean, no_manager?:boolean, settings?:distant.plugin.Settings}
--- @return spec.e2e.Driver
function M:setup(opts)
    opts = opts or {}

    -- Create a new instance and assign the session to it
    --- @type spec.e2e.Driver
    local instance = {}
    setmetatable(instance, M)
    instance.label = assert(opts.label, 'Missing label in setup')
    instance.tmp_dir = opts.tmp_dir or '/tmp'
    instance.__log_level = opts.log or vim.log.levels.OFF
    instance.__client = nil
    instance.__fixtures = {}

    if not opts.lazy then
        instance:initialize({
            label = opts.label,
            log_dir = opts.log_dir,
            no_client = opts.no_client,
            no_manager = opts.no_manager,
            settings = opts.settings,
        })
    end

    return instance
end

--- Initializes the driver by invoking `setup` on the plugin to start a manager
--- and then creates a local client to use for testing.
---
--- @param opts {label:string, log_dir?:string, no_client?:boolean, no_manager?:boolean, settings?:distant.plugin.Settings, timeout?:number, interval?:number}
--- @return spec.e2e.Driver
function M:initialize(opts)
    opts = opts or {}

    -- Only try to setup the plugin if not initialized yet
    if not plugin:is_initialized() then
        -- Setup our plugin with provided settings, forcing the private network for setup
        plugin:setup(vim.tbl_deep_extend('force', opts.settings or {}, {
            manager = {
                lazy = opts.no_manager == true,
            },
            network = {
                private = true,
                windows_pipe = 'nvim-test-' .. next_id(),
                unix_socket = self.tmp_dir .. '/nvim-test-' .. next_id() .. '.sock',
            }
        }), {
            wait = SETUP_TIMEOUT,
        })
    end

    -- Initialize a test client unless told explicitly not to do so
    if not opts.no_client then
        if self.__client then
            self:debug_print('Warning, client is still initialized and is being overwritten!')
        end

        self.__client = initialize_client({
            log_dir = opts.log_dir,
            timeout = opts.timeout,
            interval = opts.interval,
        })
    end

    return self
end

--- Tears down driver, cleaning up resources
function M:teardown()
    self.__client = nil

    for _, fixture in ipairs(self.__fixtures) do
        self:trace_print('Removing fixture ' .. fixture:path())
        fixture:remove({ ignore_errors = true })
    end
end

--- Returns the path to the CLI used by this driver.
--- @return string
function M:cli_path()
    return plugin:cli().path
end

--- @return integer|nil
function M:client_id()
    if self.__client then
        return self.__client.id
    end
end

-------------------------------------------------------------------------------
-- DRIVER DEBUG FUNCTIONS
-------------------------------------------------------------------------------

function M:debug_print(...)
    local unpack = unpack or table.unpack
    if self:is_log_debug_enabled() then
        local args = { ... }
        table.insert(args, 1, '[DEBUG]')
        print(unpack(args))
    end
end

function M:trace_print(...)
    local unpack = unpack or table.unpack
    if self:is_log_trace_enabled() then
        local args = { ... }
        table.insert(args, 1, '[TRACE]')
        print(unpack(args))
    end
end

--- Returns whether or not error logging is enabled.
--- @return boolean
function M:is_log_error_enabled()
    return self.__log_level <= vim.log.levels.ERROR
end

--- Returns whether or not warn logging is enabled.
--- @return boolean
function M:is_log_warn_enabled()
    return self.__log_level <= vim.log.levels.WARN
end

--- Returns whether or not info logging is enabled.
--- @return boolean
function M:is_log_info_enabled()
    return self.__log_level <= vim.log.levels.INFO
end

--- Returns whether or not debug logging is enabled.
--- @return boolean
function M:is_log_debug_enabled()
    return self.__log_level <= vim.log.levels.DEBUG
end

--- Returns whether or not trace logging is enabled.
--- @return boolean
function M:is_log_trace_enabled()
    return self.__log_level <= vim.log.levels.TRACE
end

-------------------------------------------------------------------------------
-- DRIVER CAPTURE FUNCTIONS
-------------------------------------------------------------------------------

--- @class spec.e2e.Capture
--- @field wait fun():(...)
--- @operator call(...):any

--- Creates a new capture callback that can be passed to asynchronous functions
--- that take a callback. The callback also exposes a wait method to wait
--- for the result.
---
--- @param opts? {timeout?:integer, interval?:integer}
--- @return spec.e2e.Capture
function M:new_capture(opts)
    opts = opts or {}
    local tx, rx = utils.oneshot_channel(
        tonumber(opts.timeout) or CAPTURE_TIMEOUT.MAX,
        tonumber(opts.interval) or CAPTURE_TIMEOUT.INTERVAL
    )

    local capture = { wait = rx }
    setmetatable(capture, {
        __call = function(_, ...)
            tx(...)
        end,
    })

    return capture
end

-------------------------------------------------------------------------------
-- DRIVER DETECTION FUNCTIONS
-------------------------------------------------------------------------------

--- @alias spec.e2e.RemoteOperatingSystem 'linux'|'macos'|'windows'|'unknown'
--- @alias spec.e2e.RemoteFamily 'unix'|'windows'|'unknown'

--- @type spec.e2e.RemoteOperatingSystem|nil
local cached_remote_os = nil

--- Detects the remote operating system, caching the result for future requests.
--- @param opts? {reload?:boolean}
--- @return spec.e2e.RemoteOperatingSystem
function M:detect_remote_os(opts)
    opts = opts or {}

    -- If we have a cached result and are not reloading, return it
    if cached_remote_os and not opts.reload then
        return cached_remote_os
    end

    local result

    -- Will return "macOS" upon success
    result = self:exec('sw_vers', { '-productName' }, { ignore_errors = true })
    if result.success and vim.trim(result.output) == 'macOS' then
        cached_remote_os = 'macos'
        return cached_remote_os
    end

    -- Will return "Linux" upon success
    result = self:exec('uname', { '-s' }, { ignore_errors = true })
    if result.success and vim.trim(result.output) == 'Linux' then
        cached_remote_os = 'linux'
        return cached_remote_os
    end

    -- Will return "Windows_NT" upon success
    result = self:exec('powershell.exe', {
        '-NonInteractive',
        '-Command',
        '"& {[Environment]::GetEnvironmentVariable(\'OS\')}"',
    }, { ignore_errors = true })
    if result.success and vim.trim(result.output) == 'Windows_NT' then
        cached_remote_os = 'windows'
        return cached_remote_os
    end

    cached_remote_os = 'unknown'
    return cached_remote_os
end

--- Detects the remote operating system family, caching the result for future requests.
--- @param opts? {reload?:boolean}
--- @return spec.e2e.RemoteFamily
function M:detect_remote_family(opts)
    local os = self:detect_remote_os(opts)
    if os == 'linux' or os == 'macos' then
        return 'unix'
    elseif os == 'windows' then
        return 'windows'
    else
        return 'unknown'
    end
end

--- Returns the path separator for the remote system, caching the result for future requests.
--- @param opts? {reload?:boolean}
--- @return string
function M:detect_remote_path_separator(opts)
    if self:detect_remote_family(opts) == 'windows' then
        return '\\'
    else
        return '/'
    end
end

-------------------------------------------------------------------------------
-- DRIVER EXECUTABLE FUNCTIONS
-------------------------------------------------------------------------------

--- Executes a program on the remote machine, returning its output.
--- If the command fails to be executed, an error will be thrown,
--- unless `ignore_errors` is specified as `true`, in which case
--- success will be returned as `false` with the error as `output`.
---
--- @param cmd string
--- @param args string[]
--- @param opts? spec.e2e.IgnoreErrorsOpts
--- @return {success:boolean, output:string}
function M:exec(cmd, args, opts)
    args = args or {}
    opts = opts or {}

    local net_cmd = ssh_cmd(cmd, args)
    self:trace_print('exec: ' .. vim.inspect(net_cmd))

    local out = vim.fn.system(net_cmd)
    local errno = tonumber(vim.v.shell_error)

    local success = errno == 0
    if not opts.ignore_errors then
        assert(success, 'ssh ' .. cmd .. ' failed (' .. errno .. '): ' .. out)
    end
    return { success = success, output = out }
end

--- Copies a file from a local/remote location to another local/remote location.
--- @param src string #path to file to copy (remote or local)
--- @param dst string #path to copy to (remote or local)
--- @param opts {src:'local'|'remote', dst:'local'|'remote', ignore_errors?:boolean}
--- @return boolean
function M:copy(src, dst, opts)
    local cmd = { 'scp', '-P', config.port }

    if opts.src == 'local' then
        table.insert(cmd, src)
    elseif opts.src == 'remote' then
        table.insert(cmd, config.host .. ':' .. src)
    else
        error('opts.src is invalid')
    end

    if opts.dst == 'local' then
        table.insert(cmd, dst)
    elseif opts.dst == 'remote' then
        table.insert(cmd, config.host .. ':' .. dst)
    else
        error('opts.dst is invalid')
    end

    self:trace_print('copy: ' .. vim.inspect(cmd))
    local out = vim.fn.system(cmd)
    local errno = tonumber(vim.v.shell_error)

    local success = errno == 0
    if not opts.ignore_errors then
        assert(success, 'scp failed (' .. errno .. '): ' .. out)
    end
    return success
end

-------------------------------------------------------------------------------
-- DRIVER FIXTURE OPERATIONS
-------------------------------------------------------------------------------

--- @param ext? string
--- @return string
function M:random_file_name(ext)
    local filename = 'test_file_' .. next_id()
    if type(ext) == 'string' and string.len(ext) > 0 then
        filename = filename .. '.' .. ext
    end
    return filename
end

--- @return string
function M:random_dir_name()
    return 'test_dir_' .. next_id()
end

--- @return string
function M:random_symlink_name()
    return 'test_symlink_' .. next_id()
end

--- Creates a new fixture for a file using the provided arguments
---
--- * base_path string|nil: base directory in which to create a fixture
--- * lines string[]|string: list of lines or a singular string containing contents
--- * ext string|nil: extension to use on the created file
---
--- @param opts {lines:string|string[], base_path?:string, ext?:string}
--- @return spec.e2e.RemoteFile #The new file fixture (remote_file)
function M:new_file_fixture(opts)
    opts = opts or {}
    assert(type(opts) == 'table', 'opts must be a table')
    assert(
        type(opts.lines) == 'string' or type(opts.lines) == 'table',
        'opts.lines invalid or missing'
    )

    local base_path = opts.base_path or self.tmp_dir

    -- Define our file path
    local path = base_path .. '/' .. self:random_file_name(opts.ext)

    -- Ensure our contents for the fixture is a string
    local contents = opts.lines
    if type(contents) == 'table' then
        contents = table.concat(contents, '\n')
    end

    -- Create the remote file
    local rf = self:remote_file(path)
    assert(rf:write(contents), 'Failed to populate file fixture: ' .. path)

    -- Store our new fixture in fixtures list
    table.insert(self.__fixtures, rf)

    -- Also return the fixture
    return rf
end

--- Creates a new fixture for a local file using the provided arguments
---
--- * base_path string|nil: base directory in which to create a fixture
--- * lines string[]|string: list of lines or a singular string containing contents
--- * ext string|nil: extension to use on the created file
---
--- @param opts {lines:string|string[], base_path?:string, ext?:string}
--- @return spec.e2e.LocalFile #The new file fixture (local_file)
function M:new_local_file_fixture(opts)
    opts = opts or {}
    assert(type(opts) == 'table', 'opts must be a table')
    assert(
        type(opts.lines) == 'string' or type(opts.lines) == 'table',
        'opts.lines invalid or missing'
    )

    local base_path = opts.base_path or self.tmp_dir

    -- Define our file path
    local path = base_path .. '/' .. self:random_file_name(opts.ext)

    -- Ensure our contents for the fixture is a string
    local contents = opts.lines
    if type(contents) == 'table' then
        contents = table.concat(contents, '\n')
    end

    -- Create the remote file
    local lf = self:local_file(path)
    assert(lf:write(contents), 'Failed to populate file fixture: ' .. path)

    -- Store our new fixture in fixtures list
    table.insert(self.__fixtures, lf)

    -- Also return the fixture
    return lf
end

--- Creates a new fixture for a directory using the provided arguments
---
--- * base_path string|nil: base directory in which to create a fixture
--- * items string[]|nil: items to create within directory
---
--- @param opts? {items?:(string|string[])[], base_path?:string}
--- @return spec.e2e.RemoteDir  #The new directory fixture (remote_dir)
function M:new_dir_fixture(opts)
    opts = opts or {}
    assert(type(opts) == 'table', 'opts must be a table')
    local base_path = opts.base_path or self.tmp_dir
    local path = base_path .. '/' .. self:random_dir_name()

    -- Create the remote directory
    local rd = self:remote_dir(path)
    assert(rd:make(), 'Failed to create directory fixture: ' .. rd:path())

    -- Store our new fixture in fixtures list
    table.insert(self.__fixtures, rd)

    -- Create all additional items within fixture
    local items = opts.items or {}
    for _, item in ipairs(items) do
        if type(item) == 'string' then
            local is_dir = vim.endswith(item, '/')
            if is_dir then
                local dir = rd:dir(item)
                assert(dir:make(), 'Failed to create dir: ' .. dir:path())
            else
                local file = rd:file(item)
                assert(file:touch(), 'Failed to create file: ' .. file:path())
            end
        elseif vim.tbl_islist(item) and #item == 2 then
            local symlink = rd:symlink(item[1])
            local target = rd:file(item[2]):path()
            assert(symlink:make(target), 'Failed to create symlink: ' .. symlink:path() .. ' to ' .. target)
        end
    end

    return rd
end

--- Creates a new fixture for a symlink using the provided arguments
---
--- * base_path string|nil: base directory in which to create a fixture
--- * source string: path to source that will be linked to
---
--- @param opts {source:string, base_path?:string}
--- @return spec.e2e.RemoteSymlink #The new symlink fixture (remote_symlink)
function M:new_symlink_fixture(opts)
    opts = opts or {}
    assert(type(opts) == 'table', 'opts must be a table')
    assert(type(opts.source) == 'string', 'opts.source must be a string')
    local base_path = opts.base_path or self.tmp_dir
    local path = base_path .. '/' .. self:random_symlink_name()

    -- Create the remote symlink
    local rl = self:remote_symlink(path)
    assert(rl:make(opts.source), 'Failed to create symlink: ' .. rl:path())

    -- Store our new fixture in fixtures list
    table.insert(self.__fixtures, rl)

    return rl
end

-------------------------------------------------------------------------------
-- DRIVER WINDOW OPERATIONS
-------------------------------------------------------------------------------

--- @param win? number #if not provided, will default to current window
--- @return spec.e2e.Window
function M:window(win)
    win = win or vim.api.nvim_get_current_win()
    return Window:new({ driver = self, id = win })
end

-------------------------------------------------------------------------------
-- DRIVER BUFFER OPERATIONS
-------------------------------------------------------------------------------

--- Creates a new buffer.
--- @param contents string|string[]
--- @param opts? {force?:boolean, modified?:boolean}
--- @return spec.e2e.Buffer
function M:make_buffer(contents, opts)
    opts = opts or {}
    local buf = vim.api.nvim_create_buf(true, false)
    assert(buf ~= 0, 'failed to create buffer')

    local buffer = self:buffer(buf)

    local lines = contents
    if type(lines) == 'string' then
        --- @type string[]
        lines = vim.split(lines, '\n', { plain = true })
    end

    buffer:set_lines(lines, opts)

    return buffer
end

--- @param buf? number #if not provided, will default to current buffer
--- @return spec.e2e.Buffer
function M:buffer(buf)
    buf = buf or vim.api.nvim_get_current_buf()
    return Buffer:new({ id = buf })
end

-------------------------------------------------------------------------------
-- DRIVER REMOTE DIRECTORY OPERATIONS
-------------------------------------------------------------------------------

--- @param remote_path string|string[]
--- @return spec.e2e.RemoteDir
function M:remote_dir(remote_path)
    assert(type(remote_path) == 'string', 'remote_path must be a string')
    return RemoteDir:new({ driver = self, path = remote_path })
end

-------------------------------------------------------------------------------
-- DRIVER REMOTE FILE OPERATIONS
-------------------------------------------------------------------------------

--- @alias spec.e2e.IgnoreErrorsOpts {ignore_errors?:boolean}

--- @param remote_path string|string[]
--- @return spec.e2e.RemoteFile
function M:remote_file(remote_path)
    assert(type(remote_path) == 'string', 'remote_path must be a string')
    return RemoteFile:new({ driver = self, path = remote_path })
end

-------------------------------------------------------------------------------
-- DRIVER REMOTE SYMLINK OPERATIONS
-------------------------------------------------------------------------------

--- @param remote_path string
--- @return spec.e2e.RemoteSymlink
function M:remote_symlink(remote_path)
    assert(type(remote_path) == 'string', 'remote_path must be a string')
    return RemoteSymlink:new({ driver = self, path = remote_path })
end

-------------------------------------------------------------------------------
-- DRIVER LOCAL FILE OPERATIONS
-------------------------------------------------------------------------------

--- @param path string|string[]
--- @return spec.e2e.LocalFile
function M:local_file(path)
    assert(type(path) == 'string', 'path must be a string')
    return LocalFile:new({ path = path })
end

return M
