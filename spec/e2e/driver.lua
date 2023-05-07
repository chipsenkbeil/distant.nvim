local config = require('spec.e2e.config')
local editor = require('distant.editor')
local state = require('distant.state')
local auth = require('distant-core').auth
local settings = require('distant-core').settings

local Buffer = require('spec.e2e.driver.buffer')
local LocalFile = require('spec.e2e.driver.local_file')
local RemoteDir = require('spec.e2e.driver.remote_dir')
local RemoteFile = require('spec.e2e.driver.remote_file')
local RemoteSymlink = require('spec.e2e.driver.remote_symlink')
local Window = require('spec.e2e.driver.window')

--- @alias spec.e2e.Fixture spec.e2e.RemoteDir|spec.e2e.RemoteFile|spec.e2e.RemoteSymlink

--- @class spec.e2e.Driver
--- @field label string
--- @field private __debug boolean
--- @field private __client? distant.Client #active client being used by this driver
--- @field private __manager? distant.Manager #active manager being used by this driver
--- @field private __fixtures spec.e2e.Fixture[] #fixtures managed by this driver
--- @field private __mode 'distant'|'ssh' #mode in which the driver is being run
local M = {}
M.__index = M

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

local function launch_mode(opts)
    opts = opts or {}
    return opts.mode or config.mode or 'distant'
end

-------------------------------------------------------------------------------
-- DRIVER SETUP & TEARDOWN
-------------------------------------------------------------------------------

--- @type distant.Client|nil
local client = nil

--- @type distant.Manager|nil
local manager = nil

--- Initialize a client if one has not been initialized yet
--- @param opts? {args?:string[], mode?:'distant'|'ssh', timeout?:number, interval?:number}
--- @return distant.Client
local function initialize_client(opts)
    opts = opts or {}
    if client ~= nil then
        return client
    end

    local timeout = opts.timeout or config.timeout
    local interval = opts.interval or config.timeout_interval

    local log_file = vim.fn.tempname()

    -- Print out our log location and flush to ensure that it shows up in case we get stuck
    print('Logging initialized', log_file)
    io.stdout:flush()

    -- Attempt to launch and connect to a remote session
    -- NOTE: We bump up our port range as tests are run in parallel and each
    --       stand up a new distant connection AND server, meaning we need
    --       to avoid running out of ports!
    -- TODO: Because of the above situation, should we instead have drivers use
    --       the same connection and only have one perform an actual launch?
    local host = config.host
    local distant_bin = config.bin

    --- @diagnostic disable-next-line:missing-parameter
    local distant_args = vim.list_extend({
        '--current-dir', config.root_dir,
        '--shutdown', 'lonely=60',
        '--port', '8080:8999',
    }, opts.args or {})

    local options = {}
    if config.ssh_backend then
        options['ssh.backend'] = config.ssh_backend
    end

    local dummy_auth = auth.handler()

    -- All password challenges return the same password
    --- @diagnostic disable-next-line:duplicate-set-field
    dummy_auth.on_challenge = function(_, msg)
        local answers = {}
        local i = 1
        local n = tonumber(#msg.questions)
        while i <= n do
            table.insert(answers, config.password or '')
            i = i + 1
        end
        return answers
    end

    -- Verify any host received
    --- @diagnostic disable-next-line:duplicate-set-field
    dummy_auth.on_verification = function(_, _) return true end

    -- Errors should fail completely
    --- @diagnostic disable-next-line:duplicate-set-field
    dummy_auth.on_error = function(_, err) error(err) end

    -- If mode is distant, launch, otherwise if mode is ssh, connect
    local mode = launch_mode(opts)
    if mode == 'distant' then
        local destination = host
        if config.user then
            destination = config.user .. '@' .. destination
        end
        destination = 'ssh://' .. destination
        local launch_opts = {
            destination = destination,
            auth = dummy_auth,
            distant = {
                bin = distant_bin,
                args = distant_args,
            },
            options = options,
        }

        editor.launch(launch_opts, function(err, c)
            if err then
                local desc = string.format(
                    'editor.launch({ destination = %s, distant_bin = %s, distant_args = %s })',
                    destination, distant_bin, vim.inspect(distant_args)
                )
                error(string.format(
                    'For %s, failed: %s',
                    desc, err
                ))
            else
                client = c
            end
        end)
    elseif mode == 'ssh' then
        local destination = 'ssh://' .. host
        editor.connect({
            destination = destination,
            auth = dummy_auth,
        }, function(err, c)
            if err then
                local desc = string.format(
                    'editor.connect({ destination = %s })',
                    destination
                )
                error(string.format(
                    'For %s, failed: %s',
                    desc, err
                ))
            else
                client = c
            end
        end)
    else
        error('Unsupported mode: ' .. mode)
    end

    local _, status = vim.wait(timeout, function()
        return client ~= nil
    end, interval)

    if client then
        return client
    end

    if status then
        error('Client not initialized in time (status == ' .. status .. ')')
    else
        error('Client not initialized in time (status == ???)')
    end
end

--- Initialize a manager if one has not been initialized yet
--- @param opts {label:string, bin?:string, network?:distant.manager.Network, timeout?:number, interval?:number}
--- @return distant.Manager
local function initialize_manager(opts)
    opts = opts or {}
    if manager ~= nil then
        return manager
    end

    local label = opts.label
    if label then
        opts.network = vim.tbl_extend('keep', config.network or {}, {
            windows_pipe = 'nvim-test-' .. label .. '-' .. next_id(),
            unix_socket = '/tmp/nvim-test-' .. label .. '-' .. next_id() .. '.sock',
        })
    end

    local err, local_manager = state:load_manager({
        bin = opts.bin,
        network = opts.network,
        timeout = opts.timeout,
        interval = opts.interval,
    })
    assert(not err, err)
    manager = assert(local_manager, 'load_manager did not return a manager')

    return manager
end

--- Initializes a driver for e2e tests.
--- @param opts {label:string, debug?:boolean, lazy?:boolean, settings?:table<string, distant.Settings>}
--- @return spec.e2e.Driver
function M:setup(opts)
    opts = opts or {}

    if type(opts.settings) == 'table' then
        settings.merge(opts.settings)
    end

    -- Create a new instance and assign the session to it
    local instance = {}
    setmetatable(instance, M)
    instance.label = assert(opts.label, 'Missing label in setup')
    instance.__debug = opts.debug or false
    instance.__client = nil
    instance.__manager = nil
    instance.__fixtures = {}
    instance.__mode = launch_mode(opts)

    if not opts.lazy then
        instance:initialize(opts)
    end

    return instance
end

--- Initializes the client of the driver.
--- @param opts table
--- @return spec.e2e.Driver
function M:initialize(opts)
    opts = opts or {}

    if type(opts.settings) == 'table' then
        settings.merge(opts.settings)
    end

    -- NOTE: Need to initialize early as driver is conflicting with itself
    --       due to random not being random enough between driver tests
    --       to prevent the same socket/windows pipe conflicting between
    --       multiple managers
    self.__manager = initialize_manager(opts)

    self.__client = initialize_client(opts)
    return self
end

--- Tears down driver, cleaning up resources
function M:teardown()
    self.__client = nil
    self.__manager = nil

    for _, fixture in ipairs(self.__fixtures) do
        fixture:remove({ ignore_errors = true })
    end
end

--- Returns the mode the driver is in (distant|ssh)
--- @return 'distant'|'ssh'
function M:mode()
    return self.__mode
end

-------------------------------------------------------------------------------
-- DRIVER DEBUG FUNCTIONS
-------------------------------------------------------------------------------

--- Prints using `print` when configured for debugging.
--- @param ... any
function M:debug_print(...)
    local unpack = unpack or table.unpack
    if self:is_debug_enabled() then
        local args = { ... }
        table.insert(args, 1, '[DEBUG]')
        print(unpack(args))
    end
end

--- Returns whether or not debugging is enabled.
--- @return boolean
function M:is_debug_enabled()
    return self.__debug
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

    local out = vim.fn.system(ssh_cmd(cmd, args))
    local errno = tonumber(vim.v.shell_error)

    local success = errno == 0
    if not opts.ignore_errors then
        assert(success, 'ssh ' .. cmd .. ' failed (' .. errno .. '): ' .. out)
    end
    return { success = success, output = out }
end

--- @param src string #path to file to copy (remote or local)
--- @param dst string #path to copy to (remote or local)
--- @param opts {src:'local'|'remote', dst:'local'|'remote', ignore_errors?:boolean}
--- @return boolean
function M:scp(src, dst, opts)
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
--- @return spec.e2e.RemoteFile #The new file fixture (remote_file)
function M:new_file_fixture(opts)
    opts = opts or {}
    assert(type(opts) == 'table', 'opts must be a table')
    assert(
        type(opts.lines) == 'string' or vim.tbl_islist(opts.lines),
        'opts.lines invalid or missing'
    )

    local base_path = opts.base_path or '/tmp'

    -- Define our file path
    local path = base_path .. '/' .. self:random_file_name(opts.ext)

    -- Ensure our contents for the fixture is a string
    local contents = opts.lines
    if vim.tbl_islist(contents) then
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

--- Creates a new fixture for a directory using the provided arguments
---
--- * base_path string|nil: base directory in which to create a fixture
--- * items string[]|nil: items to create within directory
---
--- @return spec.e2e.RemoteDir  #The new directory fixture (remote_dir)
function M:new_dir_fixture(opts)
    opts = opts or {}
    assert(type(opts) == 'table', 'opts must be a table')
    local base_path = opts.base_path or '/tmp'
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
--- @return spec.e2e.RemoteSymlink #The new symlink fixture (remote_symlink)
function M:new_symlink_fixture(opts)
    opts = opts or {}
    assert(type(opts) == 'table', 'opts must be a table')
    assert(type(opts.source) == 'string', 'opts.source must be a string')
    local base_path = opts.base_path or '/tmp'
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
--- @param opts? {modified?:boolean}
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
