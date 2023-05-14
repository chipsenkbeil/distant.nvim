--- Represents a structured destination.
--- @class distant.core.Destination
--- @field host string
--- @field port? integer
--- @field scheme? string
--- @field username? string
--- @field password? string
local M   = {}
M.__index = M

--- Creates a new destination.
--- @param opts {host:string, port?:integer, scheme?:string, username?:string, password?:string}
--- @return distant.core.Destination
function M:new(opts)
    local instance = {}
    setmetatable(instance, M)
    instance.host     = assert(opts.host, 'Destination missing host')
    instance.port     = tonumber(opts.port)
    instance.scheme   = opts.scheme
    instance.username = opts.username
    instance.password = opts.password

    return instance
end

--- Creates a new destination from parsing a string. Will throw an error if unable to parse.
---
--- Format for a destination is [SCHEME://][[USER][:PASSWORD]@]HOST[:PORT] where everything
--- in square brackets is optional.
---
--- @param input string
--- @return distant.core.Destination
function M:parse(input)
    local destination = tostring(input)

    --- Parse scheme, returning {new_str}, {scheme} where scheme can be nil
    local function parse_scheme(s)
        local i, j = string.find(s, '.+://')
        local scheme

        -- Not matching at start, so exit!
        if i ~= 1 then
            return s
        end

        -- If we have a match, get the scheme as everything before ://
        -- and update our overall string to be everything after ://
        if i ~= nil and j ~= nil and j > 3 then
            scheme = string.sub(s, i, j - 3)
            s = string.sub(s, j + 1)
        end

        return s, scheme
    end

    --- Parse username/password, returning {new_str}, {username}, {password} where username/password can be nil
    ---
    --- Additionally, username will be empty string if it is not provided but a password is.
    --- Same situation with username provided but no password
    local function parse_username_password(s)
        local username, password, i, has_password, is_valid, old_s
        i = 1
        username = ''
        password = ''
        has_password = false
        is_valid = false
        old_s = s

        -- Build up our username
        while i <= #s do
            local c = string.sub(s, i, i)
            if c == ':' then
                has_password = true
                break
            elseif c == '@' then
                is_valid = true
                break
            else
                username = username .. c
            end

            i = i + 1
        end

        -- Update destination string to everything after username (and optional : or @)
        s = string.sub(s, i + 1)

        -- Build up our password
        if has_password then
            i = 1
            while i <= #s do
                local c = string.sub(s, i, i)
                if c == '@' then
                    is_valid = true
                    break
                else
                    password = password .. c
                end

                i = i + 1
            end

            -- Update destination string to everything after password (and @)
            s = string.sub(s, i + 1)
        end

        -- Assert that our string starts with @ for username/password parsing
        if is_valid then
            return s, username, password
        else
            return old_s
        end
    end

    --- Parse host/port, returning {new_str}, {host}, {port} where port can be nil
    local function parse_host_port(s)
        local host, port, i, has_port, old_s
        host = ''
        port = nil
        i = 1
        has_port = false
        old_s = s

        -- Build up our host
        while i <= #s do
            local c = string.sub(s, i, i)
            if c == ':' then
                has_port = true
                break
            else
                host = host .. c
            end

            i = i + 1
        end

        -- Update destination string to everything after host (and optional :)
        s = string.sub(s, i + 1)

        -- Build up our port
        if has_port then
            port = tonumber(s)
            s = ''
        end

        -- If we have a port but it was invalid, we want to return our old s
        -- because this isn't a valid host[:port] combination
        if has_port and not port then
            return old_s
        else
            return s, host, port
        end
    end

    local scheme, username, password, host, port
    destination, scheme = parse_scheme(destination)
    destination, username, password = parse_username_password(destination)
    destination, host, port = parse_host_port(destination)

    if type(username) == 'string' and #username == 0 then
        username = nil
    end

    if type(password) == 'string' and #password == 0 then
        password = nil
    end

    -- If destination still has content remaining, return nil result!
    -- If host is empty, return nil result!
    if #destination > 0 or not host or #host == 0 then
        error('Unable to parse destination!')
    end

    return M:new({
        scheme = scheme,
        username = username,
        password = password,
        host = host,
        port = port,
    })
end

--- Creates a new destination from parsing a string. Will return nil if unable to parse.
--- @param input string
--- @return distant.core.Destination|nil
function M:try_parse(input)
    local success, destination = pcall(self.parse, self, input)
    if success then
        return destination
    end
end

--- Returns destination as a string in the form
--- [SCHEME://][[USER][:PASSWORD]@]HOST[:PORT].
---
--- @return string
function M:as_string()
    --- @type string[]
    local s = {}

    if self.scheme then
        table.insert(s, self.scheme)
        table.insert(s, '://')
    end

    if self.username then
        table.insert(s, self.username)
    end

    if self.password then
        table.insert(s, ':')
        table.insert(s, self.password)
    end

    if self.username or self.password then
        table.insert(s, '@')
    end

    table.insert(s, self.host)

    if self.port then
        table.insert(s, ':')
        table.insert(s, tostring(self.port))
    end

    return table.concat(s, '')
end

--- Returns destination as a string.
--- @return string
function M:__tostring()
    return self:as_string()
end

return M
