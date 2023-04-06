local utils = require('distant-core.utils')

local Client = require('distant-core.cli.client')
local install = require('distant-core.cli.install')
local Manager = require('distant-core.cli.manager')

local cli = {}

--- Minimum version supported by the cli, also enforcing
--- version upgrades such that 0.17.x would not allow 0.18.0+
--- @type Version
local MIN_VERSION = assert(utils.parse_version('0.20.0-alpha.5'))

--- @param opts ClientConfig
--- @return Client
function cli.client(opts)
    local settings = cli.settings(opts)
    opts = opts or {}
    opts.binary = opts.binary or settings.bin

    return Client:new(opts)
end

--- @param opts ManagerConfig
--- @return Manager
function cli.manager(opts)
    local settings = cli.settings(opts)
    opts = opts or {}
    opts.binary = opts.binary or settings.bin

    return Manager:new(opts)
end

--- @class CliSettingsOpts
--- @field bin? string #path to the binary
--- @field timeout? number #maximum timeout in milliseconds for a request
--- @field interval? number #time in milliseconds to wait between checking for a request to complete
--- @field no_install_fallback? boolean #if true, will not swap bin with install path if missing/not executable

--- @param opts CliSettingsOpts
--- @return {bin:string, timeout:number, interval:number}
function cli.settings(opts)
    opts = opts or {}

    -- NOTE: Must load state lazily here, otherwise we get a loop
    local state = require('distant-core.state')

    -- If we are not given a custom bin path, the settings bin path
    -- hasn't changed (from distant/distant.exe), and the current
    -- bin path isn't executable, then check if the install path
    -- exists and is executable and use it
    local bin = opts.bin or state.settings.client.bin
    local is_bin_generic = bin == 'distant' or bin == 'distant.exe'
    if not opts.no_install_fallback and is_bin_generic and vim.fn.executable(bin) ~= 1 then
        bin = install.path()
    end

    return {
        bin = bin,
        timeout = opts.timeout or state.settings.max_timeout,
        interval = opts.interval or state.settings.timeout_interval,
    }
end

--- Returns a copy of the minimum version of the CLI supported
--- @return Version
function cli.min_version()
    return vim.deepcopy(MIN_VERSION)
end

--- Retrieves the current version of the binary, returning it  or nil if not available
--- @overload fun():Version|nil
--- @param opts CliSettingsOpts #Setting options
--- @return Version|nil
function cli.version(opts)
    local settings = cli.settings(opts)
    return utils.exec_version(settings.bin)
end

--- @overload fun():boolean
--- @param opts CliSettingsOpts #Setting options
--- @return boolean #true if the binary used by this cli exists and is executable
function cli.is_executable(opts)
    local settings = cli.settings(opts)
    return vim.fn.executable(settings.bin) == 1
end

--- Checks if the cli binary is available on path, and installs the binary if
--- it is not. Will also check the version and attempt to install the binary if
--- the available version fails our check.
--- @overload fun(cb:fun(err:string|nil, path:string|nil))
--- @param opts {bin?:string, reinstall?:boolean, timeout?:number, interval?:number} #Optional installation options
--- @param cb fun(err:string|nil, path:string|nil) #Path is the path to the installed binary
function cli.install(opts, cb)
    if not cb then
        cb = opts
        opts = {}
    end

    if not opts then
        opts = {}
    end

    local settings = cli.settings(opts)
    local has_bin = vim.fn.executable(settings.bin) == 1

    --- @param bin string #Path to binary
    --- @return boolean
    local function validate_cli(bin)
        local version = cli.version({ bin = bin })
        if not version then
            return cb('Unable to detect binary version')
        end
        local ok = utils.can_upgrade_version(
            MIN_VERSION,
            version,
            { allow_unstable_upgrade = true }
        )

        if ok then
            vim.schedule(function() cb(nil, bin) end)
        end

        return ok
    end

    -- If the cli's binary is available, check if it's valid and
    -- if so we can exit
    if has_bin and validate_cli(settings.bin) then
        return
    end

    -- Otherwise, try to install to our internal location and use it
    return install.install({
        min_version = MIN_VERSION,
        reinstall = opts.reinstall,
    }, function(success, result)
        if not success then
            return cb(result)
        else
            validate_cli(result)
        end
    end)
end

return cli
