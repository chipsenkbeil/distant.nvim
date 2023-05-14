local utils = require('distant-core').utils

--- Name of buffer variable where all data is stored.
local VARNAME = 'distant'

--- Information stored relative to the buffer.
--- @class distant.plugin.buffer.Data
--- @field client_id string
--- @field path? string
--- @field alt_paths? string[]
--- @field type? distant.plugin.buffer.Type

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
    --- @param id string
    --- @return boolean
    function M.set_client_id(id)
        local data = get_data() or {}
        data.client_id = id
        return set_data(data)
    end

    --- Returns the id of the client tied to the remote machine associated with this buffer.
    --- Can be nil if not configured as a distant buffer.
    --- @return string|nil
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

    --- Scans all path variables to see if there is a matching path.
    --- @param path string
    --- @return boolean
    function M.has_matching_path(path)
        -- If not initialized or invalid path, we can exit early
        if not M.has_data() or type(path) ~= 'string' or path:len() == 0 then
            return false
        end

        -- Simplify the path we are searching for to be the local
        -- portion without a trailing slash or distant:// scheme
        path = remove_trailing_slash(utils.strip_prefix(path, 'distant://'))

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
    ---
    --- @param opts {path:string}
    --- @return distant.plugin.Buffer|nil
    function M.find(opts)
        local path = opts.path
        if type(path) == 'string' then
            -- Simplify the path we are searching for to be the local
            -- portion without a trailing slash or distant:// scheme
            path = remove_trailing_slash(utils.strip_prefix(path, 'distant://'))

            -- Check if we have a buffer in the form of distant://path
            --- @diagnostic disable-next-line:param-type-mismatch
            local bufnr = vim.fn.bufnr('^distant://' .. path .. '$', 0)
            if bufnr ~= -1 then
                return make_buffer(bufnr)
            end

            -- Otherwise, we look through all buffers to see if the path is set
            -- as the primary or one of the alternate paths
            --- @diagnostic disable-next-line:redefined-local
            for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
                if make_buffer(bufnr).has_matching_path(path) then
                    return make_buffer(bufnr)
                end
            end
        end
    end

    --- Like `buf.find`, but returns the buffer number instead of the buffer.
    --- @param opts {path:string}
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
