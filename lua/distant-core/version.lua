local unpack = unpack or table.unpack

--- Represents a structured version.
--- @class distant.core.Version
--- @field major integer
--- @field minor? integer
--- @field patch? integer
--- @field prerelease? string[]
--- @field build? string[]
local M      = {}
M.__index    = M

--- Creates a new version.
--- @param opts {major:integer, minor?:integer, patch?:integer, prerelease?:string[], build?:string[]}
--- @return distant.core.Version
function M:new(opts)
    local instance = {}
    setmetatable(instance, M)
    instance.major = opts.major
    instance.minor = opts.minor
    instance.patch = opts.patch
    instance.prerelease = opts.prerelease
    instance.build = opts.build
    return instance
end

-------------------------------------------------------------------------------
--- PARSING API
-------------------------------------------------------------------------------

--- @param identifiers string[]
local function validate_identifiers(identifiers)
    for _, identifier in ipairs(identifiers) do
        local num

        -- Empty identifiers are not allowed
        if identifier:len() == 0 then
            error('identifier cannot be empty', 2)
        end

        -- Only attempt to parse as a number if we are NOT
        -- starting with a hyphen, as that is an identifier
        -- but not a numeric one!
        if identifier:sub(1, 1) ~= '-' then
            num = tonumber(identifier)
        end

        -- Rules for semver 2.0.0 state that numeric identifiers cannot start with 0
        -- and string identifiers can only be comprised of alphanumeric characters and -
        if num ~= nil and identifier:sub(1, 1) == '0' then
            error('numeric identifier cannot start with 0', 2)
        elseif identifier:match('[^%w%-]') then
            error('string identifier can only contain alphanumeric characters and -', 2)
        end
    end
end

--- Creates a new version from parsing a string. Will throw an error if unable to parse.
---
--- If `opts.strict` is true, `semver` must represent a complete version in the form of
--- `x.y.z` with an optional prerelease version and build metadata.
---
--- Otherwise, version strings without minor or patch versions will be accepted.
---
--- @param semver string
--- @param opts? {strict?:boolean}
--- @return distant.core.Version
function M:parse(semver, opts)
    local strict = (opts or {}).strict == true

    --- @type string|nil, string|nil
    local prerelease, build

    --- @type integer|nil
    local i

    -- Check if we have build metadata by looking for the first +
    i = semver:find('%+')
    if i ~= nil then
        build = semver:sub(i + 1)
        semver = semver:sub(1, i - 1)
    end

    -- Check if we have a prerelease version by looking for the first -
    i = semver:find('%-')
    if i ~= nil then
        prerelease = semver:sub(i + 1)
        semver = semver:sub(1, i - 1)
    end

    -- Break out version into major, minor, and patch
    local major, minor, patch = unpack(vim.split(semver, '.', { plain = true }))

    -- If we have have a prerelease version, we want to parse it
    if prerelease then
        --- @diagnostic disable-next-line:cast-local-type
        prerelease = vim.split(prerelease, '.', { plain = true })
        validate_identifiers(prerelease)
    end

    -- If we have have  build metadata, we want to parse it
    if build then
        --- @diagnostic disable-next-line:cast-local-type
        build = vim.split(build, '.', { plain = true })
        validate_identifiers(build)
    end

    -- Convert our minor and patch to numbers, failing if strict is set
    if strict then
        minor = assert(tonumber(minor), 'minor version not numeric')
        patch = assert(tonumber(patch), 'patch version not numeric')
    else
        minor = minor and assert(tonumber(minor), 'minor version not numeric')
        patch = patch and assert(tonumber(patch), 'patch version not numeric')
    end

    return M:new({
        major = assert(tonumber(major), 'major version not numeric'),
        minor = minor,
        patch = patch,
        prerelease = prerelease,
        build = build,
    })
end

--- Creates a new version from parsing a string. Will return nil if unable to parse.
--- @param semver string
--- @param opts? {strict?:boolean}
--- @return distant.core.Version|nil
function M:try_parse(semver, opts)
    local success, version = pcall(self.parse, self, semver, opts)
    if success then
        return version
    end
end

-------------------------------------------------------------------------------
--- INCREMENT API
-------------------------------------------------------------------------------

--- @alias distant.core.version.Level
--- | '"major"'
--- | '"minor"'
--- | '"patch"'

--- Increments this version by the specified `level`, returning a new copy as a result.
---
--- * If no `level` is provided, defaults to "patch".
--- * If `minor` or `patch` is missing, they will be set to 0 prior to incrementing.
---
--- @param level? distant.core.version.Level
--- @return distant.core.Version
function M:inc(level)
    local version = M:new({
        major = self.major,
        minor = self.minor or 0,
        patch = self.patch or 0,
        prerelease = vim.deepcopy(self.prerelease),
        build = vim.deepcopy(self.build),
    })

    level = level or 'patch'

    if level == 'major' then
        version.major = version.major + 1
        version.minor = 0
        version.patch = 0
        version.prerelease = nil
        version.build = nil
    elseif level == 'minor' then
        version.minor = version.minor + 1
        version.patch = 0
        version.prerelease = nil
        version.build = nil
    elseif level == 'patch' then
        version.patch = version.patch + 1
        version.prerelease = nil
        version.build = nil
    end

    return version
end

-------------------------------------------------------------------------------
--- COMPARISON API
-------------------------------------------------------------------------------

--- Compares this version with the `other` version following semver 2.0.0 specification.
---
--- * Returns -1 if lower precedence than `other` version.
--- * Returns 0 if equal precedence to `other` version.
--- * Returns 1 if higher precedence than `other` version.
---
--- Missing `minor` and `patch` versions are treated as 0.
---
--- @param other distant.core.Version
--- @return -1|0|1 result
function M:cmp(other)
    --- @param a integer|string
    --- @param b integer|string
    --- @return -1|0|1
    local function diff(a, b)
        if a < b then
            return -1
        elseif a > b then
            return 1
        else
            return 0
        end
    end

    local cmp
    cmp = diff(self.major, other.major)
    if cmp ~= 0 then
        return cmp
    end

    cmp = diff(self.minor or 0, other.minor or 0)
    if cmp ~= 0 then
        return cmp
    end

    cmp = diff(self.patch or 0, other.patch or 0)
    if cmp ~= 0 then
        return cmp
    end

    local self_has_prerelease = self:has_prerelease()
    local other_has_prerelease = other:has_prerelease()

    -- Prerelease version has lower precedence than normal version
    if self_has_prerelease and not other_has_prerelease then
        return -1
    end

    -- Normal version has higher precedence than prerelease version
    if not self_has_prerelease and other_has_prerelease then
        return 1
    end

    if self_has_prerelease and other_has_prerelease then
        --- @type string[]
        local self_prerelease = self.prerelease

        --- @type string[]
        local other_prerelease = other.prerelease

        for i = 1, math.min(#self_prerelease, #other_prerelease) do
            local self_identifier = self_prerelease[i]
            local other_identifier = other_prerelease[i]
            local self_identifier_num = tonumber(self_identifier)
            local other_identifier_num = tonumber(other_identifier)

            -- Prerelease identifier comparison rules:
            --
            -- 1. If both numeric, compare numerically
            -- 2. If both not numeric, compare lexically in ASCII sort order
            -- 3. If mixed, numeric is lower precedence than non-numeric
            if self_identifier_num and other_identifier_num then
                cmp = diff(self_identifier_num, other_identifier_num)
                if cmp ~= 0 then
                    return cmp
                end
            elseif not self_identifier_num and not other_identifier_num then
                cmp = diff(self_identifier, other_identifier)
                if cmp ~= 0 then
                    return cmp
                end
            elseif self_identifier_num then
                return -1
            else
                return 1
            end
        end

        -- A larger set of prerelease fields has higher precedence
        if #self_prerelease < #other_prerelease then
            return -1
        elseif #self_prerelease > #other_prerelease then
            return 1
        end
    end

    return 0
end

--- Follows SemVer 2.0.0 and Cargo rulesets to see if this version satisifies the condition.
---
--- ### General check
---
--- An update is allowed if the new version number does not modify the left-most non-zero
--- digit in the major, minor, patch grouping.
---
--- ```
--- 1.2.3  :=  >=1.2.3, <2.0.0
--- 1.2    :=  >=1.2.0, <2.0.0
--- 1      :=  >=1.0.0, <2.0.0
--- 0.2.3  :=  >=0.2.3, <0.3.0
--- 0.2    :=  >=0.2.0, <0.3.0
--- 0.0.3  :=  >=0.0.3, <0.0.4
--- 0.0    :=  >=0.0.0, <0.1.0
--- 0      :=  >=0.0.0, <1.0.0
--- ```
---
--- ### Cargo distinction
---
--- This compatibility convention is different from SemVer in the way it treats
--- versions before 1.0.0. While SemVer says there is no compatibility before
--- 1.0.0, Cargo considers 0.x.y to be compatible with 0.x.z, where y ≥ z and x > 0.
---
--- @param version string|distant.core.Version # lower bound
--- @return boolean
function M:compatible(version)
    local lower_bound, upper_bound

    if type(version) == 'string' then
        lower_bound = M:parse(version)
    else
        lower_bound = version
    end

    -- Set upper bound to be the increment of the highest non-zero version
    if lower_bound.major > 0 then
        upper_bound = lower_bound:inc('major')
    elseif lower_bound.minor and lower_bound.minor > 0 then
        upper_bound = lower_bound:inc('minor')
    elseif lower_bound.patch and lower_bound.patch > 0 then
        upper_bound = lower_bound:inc('patch')
    elseif lower_bound.minor and lower_bound.patch then
        upper_bound = M:new({ major = 0, minor = 0, patch = 1 })
    elseif lower_bound.minor then
        upper_bound = M:new({ major = 0, minor = 1 })
    else
        upper_bound = M:new({ major = 1 })
    end

    return self >= lower_bound and self < upper_bound
end

-------------------------------------------------------------------------------
--- UTILITIES API
-------------------------------------------------------------------------------

--- @return boolean
function M:has_prerelease()
    return self.prerelease ~= nil and not vim.tbl_isempty(self.prerelease)
end

--- @return boolean
function M:has_build()
    return self.build ~= nil and not vim.tbl_isempty(self.build)
end

--- @return string|nil
function M:prerelease_string()
    if self:has_prerelease() then
        return table.concat(self.prerelease, '.')
    end
end

--- @return string|nil
function M:build_string()
    if self:has_build() then
        return table.concat(self.build, '.')
    end
end

--- Returns version as a string.
--- @return string
function M:as_string()
    local s = tostring(self.major)

    -- We need to display the minor if we have it
    -- or if we have a patch we display 0 for minor
    if self.minor or self.patch then
        s = s .. '.' .. tostring(self.minor or 0)
    end

    if self.patch then
        s = s .. '.' .. tostring(self.patch)
    end

    if self.prerelease then
        s = s .. '-' .. table.concat(self.prerelease, '.')
    end

    if self.build then
        s = s .. '+' .. table.concat(self.build, '.')
    end

    return s
end

-------------------------------------------------------------------------------
--- METAMETHOD API
-------------------------------------------------------------------------------

--- @param version distant.core.Version
--- @return boolean
function M:__le(version)
    return self:cmp(version) <= 0
end

--- @param version distant.core.Version
--- @return boolean
function M:__lt(version)
    return self:cmp(version) < 0
end

--- @param version distant.core.Version
--- @return boolean
function M:__eq(version)
    return self:cmp(version) == 0
end

--- @param version distant.core.Version
--- @return boolean
function M:__gt(version)
    return self:cmp(version) > 0
end

--- @param version distant.core.Version
--- @return boolean
function M:__ge(version)
    return self:cmp(version) >= 0
end

--- @return string
function M:__tostring()
    return self:as_string()
end

return M
