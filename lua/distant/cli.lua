local Client      = require('distant-core.client')
local installer   = require('distant-core.installer')
local log         = require('distant-core.log')
local Manager     = require('distant-core.manager')
local utils       = require('distant-core.utils')

--- @class DistantCli
local M           = {}

--- Minimum version supported by the cli, also enforcing
--- version upgrades such that 0.17.x would not allow 0.18.0+
local MIN_VERSION = assert(utils.parse_version('0.20.0-alpha.5'))

--- @param opts ClientConfig
--- @return DistantClient
function M.client(opts)
    local settings = M.settings(opts)
    opts = opts or {}
    opts.binary = opts.binary or settings.bin

    return Client:new(opts)
end

--- @param opts DistantManagerConfig
--- @return DistantManager
function M.manager(opts)
    local settings = M.settings(opts)
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
function M.settings(opts)
    opts = opts or {}

    -- NOTE: Must load state lazily here, otherwise we get a loop
    local state = require('distant.state')

    -- If we are not given a custom bin path, the settings bin path
    -- hasn't changed (from distant/distant.exe), and the current
    -- bin path isn't executable, then check if the install path
    -- exists and is executable and use it
    local bin = opts.bin or state.settings.client.bin
    local is_bin_generic = bin == 'distant' or bin == 'distant.exe'
    if not opts.no_install_fallback and is_bin_generic and vim.fn.executable(bin) ~= 1 then
        bin = installer.path()
    end

    return {
        bin = bin,
        timeout = opts.timeout or state.settings.max_timeout,
        interval = opts.interval or state.settings.timeout_interval,
    }
end

--- Returns a copy of the minimum version of the CLI supported
--- @return Version
function M.min_version()
    return vim.deepcopy(MIN_VERSION)
end
