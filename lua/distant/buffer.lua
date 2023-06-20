--- Name of buffer variable where all data is stored.
local VARNAME = 'distant'

--- Information stored relative to the buffer.
--- @class distant.plugin.buffer.Data
--- @field client_id distant.core.manager.ConnectionId
--- @field path? string
--- @field alt_paths? string[]
--- @field type? distant.plugin.buffer.Type
--- @field mtime? number
--- @field watched? distant.plugin.buffer.Watched

--- @alias distant.plugin.buffer.Watched
--- | false
--- | true
--- | 'locked'
--- @alias distant.plugin.buffer.Type 'dir'|'file'

--- Creates a new instance of the buffer interface.
--- @param buf? number # if not provided, will be 0 for current buffer
--- @return distant.plugin.Buffer
local function make_buffer(buf)
    -- If no buffer provided, use 0 for current buffer
    buf = buf or 0

    --- distant-oriented buffer functionality.
    --- @class distant.plugin.Buffer
    --- @operator call(number|nil):distant.plugin.Buffer
    --- @field private buf number # handle to vim buffer (or 0 for current buffer)
    local M = {}

    setmetatable(M, {
        __index = M,
        --- @param _ distant.plugin.Buffer
        --- @param buf? number
        --- @return distant.plugin.Buffer
        __call = function(_, buf)
            assert(
                buf == nil or type(buf) == 'number',
                ('buf() given invalid value: %s'):format(vim.inspect(buf))
            )
            return make_buffer(buf)
        end
    })

    --------------------------------------------------------------------------
    -- DATA API
    --------------------------------------------------------------------------

    --- Retrieves buffer data.
    --- @return distant.plugin.buffer.Data|nil
    local function get_data()
        local success, tbl = pcall(vim.api.nvim_buf_get_var, buf, VARNAME)
        if success and type(tbl) == 'table' then
            return tbl
        end
    end

    --- Sets buffer data.
    --- @param data distant.plugin.buffer.Data
    --- @return boolean
    local function set_data(data)
        local success = pcall(vim.api.nvim_buf_set_var, buf, VARNAME, data)
        return success
    end

    --- Deletes buffer data.
    --- @return boolean
    local function clear_data()
        local success = pcall(vim.api.nvim_buf_del_var, buf, VARNAME)
        return success
    end

    --- Returns the number of the buffer handle.
    --- @return number
    function M.bufnr()
        return buf
    end

    --- Sets all distant data assocaited with this buffer.
    --- @param data distant.plugin.buffer.Data
    --- @return boolean
    function M.set_data(data)
        return set_data(data)
    end

    --- Mutates all distant data assocaited with this buffer. If no data is associated
    --- with the buffer, will throw an error.
    --- @param mutate_fn fun(data:distant.plugin.buffer.Data):distant.plugin.buffer.Data
    --- @return boolean
    function M.mutate_data(mutate_fn)
        local data = mutate_fn(assert(get_data(), 'Buffer missing distant data'))
        return set_data(data)
    end

    --- Returns whether or not this buffer has distant data associated with it.
    --- @return boolean
    function M.has_data()
        return get_data() ~= nil
    end

    --- Retrieves all distant data associated with this buffer.
    --- Returns nil if the buffer does not have distant data.
    --- @return distant.plugin.buffer.Data|nil
    function M.data()
        return get_data()
    end

    --- Retrieves all distant data associated with this buffer.
    --- Asserts that this buffer has distant data.
    --- @return distant.plugin.buffer.Data
    function M.assert_data()
        return assert(get_data(), 'Buffer missing distant data')
    end

    --- Deletes all distant buffer data.
    --- @return boolean
    function M.clear()
        return clear_data()
    end

    --- Sets the local buffer data representing the id of the client tied to the remote machine.
    --- @param id distant.core.manager.ConnectionId
    --- @return boolean
    function M.set_client_id(id)
        local data = get_data() or {}
        data.client_id = id
        return set_data(data)
    end

    --- Returns the id of the client tied to the remote machine associated with this buffer.
    --- Can be nil if not configured as a distant buffer.
    --- @return distant.core.manager.ConnectionId|nil
    function M.client_id()
        local data = get_data()
        if data then
            return data.client_id
        end
    end

    --- Sets the local buffer data representing the path on the remote machine.
    --- @param path string
    --- @return boolean
    function M.set_path(path)
        local data = get_data() or {}
        data.path = path
        return set_data(data)
    end

    --- Returns the path of this buffer on the remote machine.
    --- Can be nil if not configured as a distant buffer.
    --- @return string|nil
    function M.path()
        local data = get_data()
        if data then
            return data.path
        end
    end

    --- Returns the path of this buffer on the remote machine.
    --- Asserts that the path field exists.
    --- @return string
    function M.assert_path()
        return assert(M.path(), 'Buffer missing distant.path')
    end

    --- Sets the local buffer data representing the alt paths on the remote machine.
    --- @param paths string[]
    --- @return boolean
    function M.set_alt_paths(paths)
        local data = get_data() or {}
        data.alt_paths = paths
        return set_data(data)
    end

    --- Adds a path to the alt path list.
    ---
    --- # Options
    ---
    --- * `dedup` - if true, will deduplicate alt paths after adding.
    ---
    --- @param path string
    --- @param opts? {dedup?:boolean}
    function M.add_alt_path(path, opts)
        opts = opts or {}

        local alt_paths = M.alt_paths() or {}
        table.insert(alt_paths, path)

        -- Deduplicate by building a new table whose keys are the paths,
        -- which will result in merging duplicate paths
        if opts.dedup then
            local tbl = {}
            for _, path in ipairs(alt_paths) do
                tbl[path] = true
            end
            alt_paths = vim.tbl_keys(tbl)
        end

        return M.set_alt_paths(alt_paths)
    end

    --- Returns the alternate paths of this buffer on the remote machine.
    --- Can be nil if not configured as a distant buffer.
    --- @return string[]|nil
    function M.alt_paths()
        local data = get_data()
        if data then
            return data.alt_paths
        end
    end

    --- Returns the alternative paths of this buffer on the remote machine.
    --- Asserts that the alt paths field exists.
    --- @return string[]
    function M.assert_alt_paths()
        return assert(M.alt_paths(), 'Buffer missing distant.alt_paths')
    end

    --- Sets the local buffer data representing the type on the remote machine.
    --- @param ty distant.plugin.buffer.Type
    --- @return boolean
    function M.set_type(ty)
        local data = get_data() or {}
        data.type = ty
        return set_data(data)
    end

    --- Returns the type of this buffer on the remote machine.
    --- Can be nil if not configured as a distant buffer.
    --- @return distant.plugin.buffer.Type|nil
    function M.type()
        local data = get_data()
        if data then
            return data.type
        end
    end

    --- Returns the type of this buffer on the remote machine.
    --- Asserts that the type field exists.
    --- @return distant.plugin.buffer.Type
    function M.assert_type()
        return assert(M.type(), 'Buffer missing distant.type')
    end

    --- Sets the local buffer data representing the last modification
    --- time (in seconds) since Unix epoch.
    --- @param mtime number
    --- @return boolean
    function M.set_mtime(mtime)
        local data = get_data() or {}
        data.mtime = mtime
        return set_data(data)
    end

    --- Returns last modification time (in seconds) since Unix epoch.
    --- Can be nil if not configured as a distant buffer.
    --- @return number|nil
    function M.mtime()
        local data = get_data()
        if data then
            return data.mtime
        end
    end

    --- Sets the local buffer data representing the watched status.
    --- @param watched distant.plugin.buffer.Watched|nil
    --- @return boolean
    function M.set_watched(watched)
        local data = get_data() or {}
        data.watched = watched
        return set_data(data)
    end

    --- Returns whether or not the buffer is being watched.
    --- Can be nil if not configured as a distant buffer.
    --- @return distant.plugin.buffer.Watched|nil
    function M.watched()
        local data = get_data()
        if data then
            return data.watched
        end
    end

    --------------------------------------------------------------------------
    -- NAME API
    --------------------------------------------------------------------------

    --- @alias distant.plugin.buffer.NameFormat
    --- | '"modern"' # use modern naming format (requires neovim 0.10+)
    --- | '"legacy"' # use legacy naming format

    --- @alias distant.plugin.buffer.NameComponents
    --- | {scheme:string|nil, connection:distant.core.manager.ConnectionId|nil, path:string}

    --- @alias distant.plugin.buffer.NameComponentsAndFormat
    --- | {scheme:string|nil, connection:distant.core.manager.ConnectionId|nil, format:distant.plugin.buffer.NameFormat|nil, path:string}

    --- @return distant.plugin.buffer.NameFormat
    local function default_name_format()
        -- TODO: If https://github.com/neovim/neovim/pull/23834 gets implemented, we
        --       can detect the neovim version and use the modern format; otherwise,
        --       we will be stuck with "legacy" forever
        return 'legacy'
    end

    --- Validates a string against RFC3986 to verify it is a scheme.
    ---
    --- @param scheme string
    --- @return boolean
    local function is_scheme(scheme)
        if type(scheme) ~= 'string' then
            return false
        end

        -- Must start with lowercase alphabetic character and then
        -- consist only of alphabetic, digit, '.', '+', or '-' chars
        local i, j = scheme:find('%l[%w%.%+%-]*')

        -- Must match the entire scheme exactly
        return i == 1 and j == scheme:len()
    end

    --- @class distant.plugin.buffer.Name
    local Name = {}

    --- Provides name-oriented functionality tied to the buffer.
    M.name = Name

    --- Returns the default format used by buffers for their name.
    --- @return distant.plugin.buffer.NameFormat
    function Name.default_format()
        return default_name_format()
    end

    --- @alias distant.plugin.buffer.name.PrefixOpts
    --- | {name?:string, format?:distant.plugin.buffer.NameFormat}
    --- | {scheme:string, connection?:distant.core.manager.ConnectionId, format?:distant.plugin.buffer.NameFormat}

    --- Returns the prefix tied to the buffer's name, a provided name, or builds a
    --- prefix from the given components.
    ---
    --- @param opts? distant.plugin.buffer.name.PrefixOpts
    --- @return string
    function Name.prefix(opts)
        opts = opts or {}

        -- Use provided options, or default to current buffer name and default format
        local name = opts.name
        if not opts.scheme and not name then
            name = vim.api.nvim_buf_get_name(buf)
        end

        if type(name) == 'string' then
            -- If we have a name, we want to parse it to get the components
            -- to build the prefix
            local components = Name.parse({
                format = opts.format,
                name = name,
            })

            -- Build the name without the path to get the prefix alongside the separator
            name = Name.build({
                connection = components.connection,
                format = opts.format,
                path = '',
                scheme = components.scheme,
            })
        elseif type(opts.scheme) == 'string' then
            -- If provided the scheme (and optional connection), build the name and
            -- extract the prefix portion from it
            name = Name.build({
                connection = opts.connection,
                format = opts.format,
                path = '',
                scheme = opts.scheme,
            })
        end

        --- @cast name string

        -- Chop off the ending :// from modern or legacy format
        -- or just : if it happens to have been translated to
        -- exclude the authority
        if vim.endswith(name, '://') then
            name = name:sub(1, -4)
        elseif vim.endswith(name, ':') then
            name = name:sub(1, -2)
        end

        return name
    end

    --- Constructs a full name based on components.
    ---
    --- ### Components
    ---
    --- * `connection` - the connection id of the client tied to the buffer.
    --- * `path` - the remainder of the name.
    --- * `scheme` - the scheme of the name such as "distant".
    ---
    --- ### Format
    ---
    --- * "modern" - `[{SCHEME}[+{CONNECTION}]://PATH`
    --- * "legacy" - `[{SCHEME}://[{CONNECTION}://]PATH`
    ---
    --- @param opts distant.plugin.buffer.NameComponentsAndFormat
    --- @return string
    function Name.build(opts)
        opts = opts or {}
        local path = assert(opts.path, 'Path is required')
        local format = opts.format or default_name_format()

        local name = ''
        local scheme = opts.scheme

        if format == 'modern' then
            if scheme then
                assert(is_scheme(scheme), 'Invalid scheme: ' .. scheme)
                name = name .. scheme
                if opts.connection then
                    name = name .. '+' .. tostring(opts.connection)
                end
                name = name .. '://'
            end
        elseif format == 'legacy' then
            if scheme then
                assert(is_scheme(scheme), 'Invalid scheme: ' .. scheme)
                name = name .. scheme .. '://'
                if opts.connection then
                    name = name .. tostring(opts.connection) .. '://'
                end
            end
        else
            error('Invalid name format: ' .. vim.inspect(format))
        end

        return name .. path
    end

    --- Parses the buffer's name into individual components.
    ---
    --- ### Components
    ---
    --- * `connection` - the connection id of the client tied to the buffer.
    --- * `path` - the remainder of the name.
    --- * `scheme` - the scheme of the name such as "distant".
    ---
    --- ### Format
    ---
    --- * "modern" - `[{SCHEME}[+{CONNECTION}]://PATH`
    --- * "legacy" - `[{SCHEME}://[{CONNECTION}://]PATH`
    ---
    --- @param opts? {format?:distant.plugin.buffer.NameFormat, name?:string}
    --- @return distant.plugin.buffer.NameComponents components
    function Name.parse(opts)
        opts = opts or {}
        local name = opts.name or vim.api.nvim_buf_get_name(buf)
        local format = opts.format or default_name_format()

        --- @type string|nil, distant.core.manager.ConnectionId|nil, number|nil, number|nil
        local scheme, connection, i, j

        -- Look for the scheme first
        i, j = string.find(name, '://')

        -- If we found a match, there is a scheme, so split off the scheme and name
        if type(i) == 'number' and type(j) == 'number' and i > 1 then
            scheme = string.sub(name, 1, i - 1)
            name = string.sub(name, j + 1)
        end

        if format == 'modern' then
            if scheme then
                i = string.find(scheme, '+')

                if type(i) == 'number' and i > 1 and i < scheme:len() then
                    -- Everything after the + is the connection
                    connection = assert(
                        tonumber(string.sub(scheme, i + 1)),
                        'invalid connection, must be a 32-bit unsigned integer'
                    )

                    -- Everything before the + is the scheme
                    scheme = string.sub(scheme, 1, i - 1)
                end
            end
        elseif format == 'legacy' then
            if scheme then
                -- Look for next :// which is used to separate the connection
                i, j = string.find(name, '://')

                if type(i) == 'number' and i > 1 and j < name:len() then
                    -- Everything before the :// is the connection
                    connection = assert(
                        tonumber(string.sub(name, 1, i - 1)),
                        'invalid connection, must be a 32-bit unsigned integer'
                    )

                    -- Everything after the :// is the path
                    name = string.sub(name, j + 1)
                end
            end
        else
            error('Invalid name format: ' .. vim.inspect(format))
        end

        -- Verify our scheme is valid if we got text
        assert(not scheme or is_scheme(scheme), 'Invalid scheme: ' .. vim.inspect(scheme))

        -- Return our results, with everything remaining in the name
        -- being treated as our path
        return { scheme = scheme, connection = connection, path = name }
    end

    --------------------------------------------------------------------------
    -- SEARCH API
    --------------------------------------------------------------------------

    --- Removes all trailing slashes / or \ from the end of the string.
    ---
    --- If this would result in the string being empty, the leftmost slash
    --- will be re-added to prevent removing it.
    ---
    --- @param path string
    --- @return string
    local function remove_trailing_slash(path)
        local s, _ = string.gsub(path, '[\\/]+$', '')

        -- If this results in an empty string, the entire string was comprised
        -- of slashes and we removed the root slash, so we want to restore the
        -- leftmost slash
        if path:len() > 0 and s:len() == 0 then
            s = path:sub(1, 1)
        end

        return s
    end

    --- Builds a vim file pattern to use with `vim.fn.bufnr()`.
    --- @param opts distant.plugin.buffer.NameComponentsAndFormat
    --- @return string
    local function file_pattern(opts)
        return '^' .. M.name.build(opts) .. '$'
    end

    --- Scans all path variables to see if there is a matching path.
    ---
    --- If provided the optional `connection`, will only return true
    --- if the buffer also has a matching connection.
    ---
    --- @param path string
    --- @param opts? {connection?:distant.core.manager.ConnectionId}
    --- @return boolean
    function M.has_matching_path(path, opts)
        opts = opts or {}

        -- If not initialized or invalid path, we can exit early
        if not M.has_data() or type(path) ~= 'string' or path:len() == 0 then
            return false
        end

        -- If given a connection that does not match our own, exit early
        if opts.connection and opts.connection ~= M.client_id() then
            return false
        end

        -- Parse path (representing full name) into its components
        local components = M.name.parse({ name = path })

        -- If the connection from the path doesn't match our own, exit early
        if components.connection and components.connection ~= M.client_id() then
            return false
        end

        -- Simplify the path we are searching for to be the local
        -- portion without a trailing slash
        path = remove_trailing_slash(components.path)

        -- CHECK PRIMARY PATH

        local primary_path = M.path()
        if type(primary_path) == 'string' and primary_path:len() > 0 then
            primary_path = remove_trailing_slash(primary_path)

            if path == primary_path then
                return true
            end
        end

        -- CHECK ALT PATHS

        for _, alt_path in ipairs(M.alt_paths() or {}) do
            if type(alt_path) == 'string' and alt_path:len() > 0 then
                alt_path = remove_trailing_slash(alt_path)

                if path == alt_path then
                    return true
                end
            end
        end

        -- NO MATCH

        return false
    end

    --- Searches for a buffer that matches the condition.
    ---
    --- # Conditions
    ---
    --- * `path` - if specified, will look for a buffer with matching path.
    ---   Will look for distant://path and path itself.
    --- * `connection` - will enforce that the matching buffer has the same connection.
    --- * `format` - type of buffer name to search (optional defaulting based on neovim version)
    ---
    --- @param opts {path:string, connection?:distant.core.manager.ConnectionId, format?:distant.plugin.buffer.NameFormat}
    --- @return distant.plugin.Buffer|nil
    function M.find(opts)
        local components = M.name.parse({ name = opts.path })
        local scheme = components.scheme or 'distant'
        local connection = opts.connection or components.connection
        local path = components.path

        if type(path) == 'string' then
            -- Simplify the path we are searching for to be the local
            -- portion without a trailing slash
            path = remove_trailing_slash(path)

            -- Check if we have a buffer in the form of distant[+{CONNECTION}]://path
            -- where the "+{CONNECTION}" is optional, indicating the client
            -- tied to the buffer
            --
            --- @diagnostic disable-next-line:param-type-mismatch
            local bufnr = vim.fn.bufnr(file_pattern({
                scheme = scheme,
                connection = connection,
                path = path,
                format = opts.format,
            }), 0)
            if bufnr ~= -1 then
                return make_buffer(bufnr)
            end

            -- Otherwise, we look through all buffers to see if the path is set
            -- as the primary or one of the alternate paths
            --- @diagnostic disable-next-line:redefined-local
            for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
                if make_buffer(bufnr).has_matching_path(path, { connection = connection }) then
                    return make_buffer(bufnr)
                end
            end
        end
    end

    --- Like `buf.find`, but returns the buffer number instead of the buffer.
    --- @param opts distant.plugin.buffer.NameComponentsAndFormat
    --- @return number|nil
    function M.find_bufnr(opts)
        local buffer = M.find(opts)
        if type(buffer) == 'table' then
            return buffer:bufnr()
        end
    end

    return M
end

return make_buffer()
