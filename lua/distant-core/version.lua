--- Represents a structured version.
--- @class Version
--- @field major integer
--- @field minor integer
--- @field patch integer
--- @field pre_release? string #typically something like `alpha` or `rc`
--- @field pre_release_version? integer #follows the pre-release
local M   = {}
M.__index = M

--- Creates a new version.
--- @param opts {major:integer, minor:integer, patch:integer, pre_release?:string, pre_release_version?:integer}
--- @return Version
function M:new(opts)
    local instance = {}
    setmetatable(instance, M)
    instance.major = opts.major
    instance.minor = opts.minor
    instance.patch = opts.patch
    instance.pre_release = opts.pre_release
    instance.pre_release_version = opts.pre_release_version

    return instance
end

--- Creates a new version from parsing a string. Will throw an error if unable to parse.
--- @return Version
function M:parse(vstr)
    local semver, ext = unpack(vim.split(vstr, '-', { plain = true }))
    local major, minor, patch = unpack(vim.split(semver, '.', { plain = true }))

    local pre_release, pre_release_version
    if ext then
        pre_release, pre_release_version = unpack(vim.split(ext, '.', { plain = true }))
    end

    return M:new({
        major = assert(tonumber(major), ('Expected version major to be number, but was "%s"'):format(vim.inspect(major))),
        minor = assert(tonumber(minor), ('Expected version minor to be number, but was "%s"'):format(vim.inspect(minor))),
        patch = assert(tonumber(patch), ('Expected version patch to be number, but was "%s"'):format(vim.inspect(patch))),
        pre_release = pre_release,
        pre_release_version = tonumber(pre_release_version),
    })
end

--- Creates a new version from parsing a string. Will return nil if unable to parse.
--- @return Version|nil
function M:try_parse(vstr)
    local success, version = pcall(self.parse, self, vstr)
    if success then
        return version
    end
end

--- Determines if safe to upgrade from this version to the `other` version.
--- This follows semver 2.0.0 specification.
---
--- For the pre-release, we check multiple situations
---
--- 1. Pre-release is the same (e.g. alpha == alpha) and current version is <= new version (e.g. 2 <= 4)
--- 2. Pre-release is an upgrade (e.g. alpha < beta)
--- 3. Pre-release is an upgrade to non-pre-release (e.g. alpha to full release)
---
--- Opts:
---
--- * `allow_unstable_upgrade` - if true, then it will be considered valid for
---   unstable versions (e.g. 0.1.0) to upgrade to a newer unstable version (e.g. 0.1.1)
---
--- @param other Version #version to upgrade towards
--- @param opts? {allow_unstable_upgrade?:boolean}
--- @return boolean
function M:can_upgrade_to(other, opts)
    opts = opts or {}
    local unstable = self.major == 0 or self.pre_release ~= nil

    -- If we allow for unstable upgrades, then the patch number
    -- is significant
    --
    -- NOTE: Pre-release version has a lower precedence than normal version in
    --       semver 2.0.0
    if unstable and opts.allow_unstable_upgrade then
        return self.major == other.major and
            self.minor == other.minor and
            self.patch <= other.patch and
            (
            self.pre_release < other.pre_release or
            (self.pre_release ~= nil and other.pre_release == nil) or
            (self.pre_release == other.pre_release and self.pre_release_version <= other.pre_release_version)
            )
    elseif unstable then
        return self.major == other.major and
            self.minor == other.minor and
            self.patch == other.patch and
            self.pre_release == other.pre_release
    else
        return self.major == other.major and self.minor <= other.minor
    end
end

--- Reverse of `can_upgrade_to`. Determines if safe to upgrade to this version to the `other` version.
--- This follows semver 2.0.0 specification.
---
--- For the pre-release, we check multiple situations
---
--- 1. Pre-release is the same (e.g. alpha == alpha) and current version is <= new version (e.g. 2 <= 4)
--- 2. Pre-release is an upgrade (e.g. alpha < beta)
--- 3. Pre-release is an upgrade to non-pre-release (e.g. alpha to full release)
---
--- Opts:
---
--- * `allow_unstable_upgrade` - if true, then it will be considered valid for
---   unstable versions (e.g. 0.1.0) to upgrade to a newer unstable version (e.g. 0.1.1)
---
--- @param other Version #version to upgrade towards
--- @param opts? {allow_unstable_upgrade?:boolean}
--- @return boolean
function M:can_upgrade_from(other, opts)
    return other:can_upgrade_to(self, opts)
end

--- Returns version as a string.
--- @return string
function M:as_string()
    local s = tostring(self.major) .. '.' .. tostring(self.minor) .. '.' .. tostring(self.patch)
    if self.pre_release then
        s = s .. '-' .. self.pre_release
        if self.pre_release_version then
            s = s .. '.' .. self.pre_release_version
        end
    end
    return s
end

--- Returns version as a string.
--- @return string
function M:__tostring()
    return self:as_string()
end

return M
