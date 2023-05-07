local installer = require('distant-core.installer')
local log       = require('distant-core.log')
local utils     = require('distant-core.utils')
local Version   = require('distant-core.version')

--- @class distant.Cli
--- @field bin string #path to the distant cli binary
local M         = {}
M.__index       = M

--- Creates a new instance of the cli.
--- @param opts {bin:string}
--- @return distant.Cli
function M:new(opts)
    local instance = {}
    setmetatable(instance, M)
    instance.bin = opts.bin
    return instance
end

--- Retrieves the current version of the binary, returning it or nil if not available.
--- @return distant.Version|nil
function M:version()
    if not self:is_executable() then
        return
    end

    -- Retrieve a raw version string in the form of "distant x.y.z-aaa.bbb"
    local raw_version = vim.fn.system(self.bin .. ' --version')
    if not raw_version then
        return
    end

    --- Remove the "distant" prefix and parse the version into a structured type
    local version_string = vim.trim(utils.strip_prefix(
        vim.trim(raw_version),
        'distant'
    ))
    if not version_string then
        return
    end

    return Version:try_parse(version_string)
end

--- Returns true if the binary pointed to is executable.
--- @return boolean
function M:is_executable()
    return vim.fn.executable(self.bin) == 1
end

--- Checks if the cli binary is available on path, and installs the binary if
--- it is not. Will also check the version and attempt to install the binary if
--- the available version fails our check. The `bin` field will be updated to
--- the installed path.
---
--- * `min_version` is required and represents the minimum supported version.
--- * `reinstall` indicates that the pre-existing `bin` will be ignored.
--- * `allow_unstable_upgrade` indicates that we will allow `0.x.x`
---
--- @param opts {min_version:distant.Version, reinstall?:boolean, timeout?:number, interval?:number}
--- @param cb fun(err?:string, path?:string) #Path is the path to the installed binary
function M:install(opts, cb)
    vim.validate({
        opts = { opts, 'table' },
        cb = { cb, 'function' },
    })

    --- @param bin string #Path to binary
    --- @return 'fail-check-version'|'invalid-version'|'ok'
    local function validate_cli(bin)
        local version = M:new({ bin = bin }):version()
        if not version then
            log.warn('Unable to detect binary version')
            return 'fail-check-version'
        end
        local ok = version:can_upgrade_from(
            opts.min_version,
            { allow_unstable_upgrade = true }
        )
        if ok then
            return 'ok'
        else
            return 'invalid-version'
        end
    end

    -- If the cli's binary is available, check if it's valid and
    -- if so we can exit
    if self:is_executable() then
        local status = validate_cli(self.bin)
        if status == 'ok' then
            vim.schedule(function() cb(nil, self.bin) end)
            return
        elseif status == 'fail-check-version' then
            vim.schedule(function() cb('Unable to detect binary version', nil) end)
            return
        end
    end

    -- Otherwise, try to install to our internal location and use it
    return installer.install({
        min_version = opts.min_version,
        reinstall = opts.reinstall,
    }, function(err, path)
        if err then
            return cb(err, nil)
        else
            local status = validate_cli(path)
            if status == 'ok' then
                self.bin = path
                cb(nil, path)
            elseif status == 'invalid-version' then
                cb('Incompatible version detected', nil)
            elseif status == 'fail-check-version' then
                cb('Unable to detect binary version', nil)
            end
        end
    end)
end

return M
