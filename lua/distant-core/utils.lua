--- @class distant.core.Utils
local M = {}

local unpack = unpack or table.unpack

local PLUGIN_NAME = 'distant.nvim'

--- @return string
M.plugin_name = function() return PLUGIN_NAME end

--- Represents the separator for use with local file system.
---
--- From https://github.com/williamboman/nvim-lsp-installer/blob/main/lua/nvim-lsp-installer/path.lua
---
--- @type '\\'|'/'
local LOCAL_SEPARATOR = (function()
    --- @diagnostic disable-next-line: undefined-global
    if jit then
        --- @diagnostic disable-next-line: undefined-global
        local os = string.lower(jit.os)
        if os == "linux" or os == "osx" or os == "bsd" then
            return "/"
        else
            return "\\"
        end
    else
        return package.config:sub(1, 1)
    end
end)()

--- Represents the local separator used by this machine.
--- @return string
M.seperator = function() return LOCAL_SEPARATOR end

--- Returns path to cache directory for this plugin.
--- @param path string|string[]|nil #if provided, will be appended to path
--- @return string
M.cache_path = function(path)
    local full_path = (
        vim.fn.stdpath('cache') ..
        M.seperator() ..
        M.plugin_name()
        )

    if type(path) == 'table' and vim.tbl_islist(path) then
        for _, component in ipairs(path) do
            full_path = full_path .. M.seperator() .. component
        end
    elseif path ~= nil then
        full_path = full_path .. M.seperator() .. path
    end

    return full_path
end

--- Returns path to data directory for this plugin.
--- @param path string|string[]|nil #if provided, will be appended to path
--- @return string
M.data_path = function(path)
    local full_path = (
        vim.fn.stdpath('data') ..
        M.seperator() ..
        M.plugin_name()
        )

    if type(path) == 'table' and vim.tbl_islist(path) then
        for _, component in ipairs(path) do
            full_path = full_path .. M.seperator() .. component
        end
    elseif path ~= nil then
        full_path = full_path .. M.seperator() .. path
    end

    return full_path
end

--- @alias distant.core.utils.OperatingSystem
--- | 'windows'
--- | 'linux'
--- | 'macos'
--- | 'dragonfly'
--- | 'freebsd'
--- | 'netbsd'
--- | 'openbsd'
--- | 'solaris'
--- | 'unknown'
---
--- @alias distant.core.utils.Architecture
--- | 'x86'
--- | 'x86_64'
--- | 'powerpc'
--- | 'arm'
--- | 'mips'
--- | 'unknown'
---
--- Retrieves the operating system and architecture of the local machine.
---
--- * Original from https://gist.github.com/soulik/82e9d02a818ce12498d1.
---
--- @return distant.core.utils.OperatingSystem os, distant.core.utils.Architecture arch
M.detect_os_arch = function()
    local raw_os_name, raw_arch_name = '', ''

    -- LuaJIT shortcut
    if jit and jit.os and jit.arch then
        raw_os_name = jit.os
        raw_arch_name = jit.arch
    else
        -- is popen supported?
        local popen_status, popen_result = pcall(io.popen, '')
        if popen_status then
            if popen_result then
                popen_result:close()
            end

            -- Unix-based OS
            raw_os_name = io.popen('uname -s', 'r'):read('*l')
            raw_arch_name = io.popen('uname -m', 'r'):read('*l')
        else
            -- Windows
            local env_OS = os.getenv('OS')
            local env_ARCH = os.getenv('PROCESSOR_ARCHITECTURE')
            if env_OS and env_ARCH then
                raw_os_name, raw_arch_name = env_OS, env_ARCH
            end
        end
    end

    raw_os_name = (raw_os_name):lower()
    raw_arch_name = (raw_arch_name):lower()

    local os_patterns = {
        ['windows'] = 'windows',
        ['linux'] = 'linux',
        ['osx'] = 'macos',
        ['mac'] = 'macos',
        ['darwin'] = 'macos',
        ['^mingw'] = 'windows',
        ['^cygwin'] = 'windows',
        ['bsd$'] = 'bsd',
        ['SunOS'] = 'solaris',
    }

    local arch_patterns = {
        ['^x86$'] = 'x86',
        ['i[%d]86'] = 'x86',
        ['amd64'] = 'x86_64',
        ['x86_64'] = 'x86_64',
        ['x64'] = 'x86_64',
        ['Power Macintosh'] = 'powerpc',
        ['^arm'] = 'arm',
        ['^mips'] = 'mips',
    }

    local os_name, arch_name = 'unknown', 'unknown'

    for pattern, name in pairs(os_patterns) do
        if raw_os_name:match(pattern) then
            os_name = name
            break
        end
    end
    for pattern, name in pairs(arch_patterns) do
        if raw_arch_name:match(pattern) then
            arch_name = name
            break
        end
    end

    -- If our OS is "bsd", we need to further distinguish the types
    if os_name == 'bsd' then
        os_name = M.bsd_os() or 'unknown'
    end

    return os_name, arch_name
end

--- @alias distant.core.utils.BSD 'netbsd'|'freebsd'|'openbsd'|'dragonfly'
--- @return distant.core.utils.BSD|nil
M.bsd_os = function()
    local has_popen = pcall(io.popen, '')
    if not has_popen then
        return
    end

    local os = vim.trim(io.popen("uname -s"):read("*a"):lower())

    if os == "netbsd" then
        return "netbsd"
    elseif os == "freebsd" then
        return "freebsd"
    elseif os == "openbsd" then
        return "openbsd"
    elseif os == "dragonfly" then
        return "dragonfly"
    end
end

--- Returns a string with the given prefix removed if it is found in the string.
--- @param s string
--- @param prefix string
--- @return string
M.strip_prefix = function(s, prefix)
    local offset = string.find(s, prefix)
    if offset == 1 then
        return string.sub(s, string.len(prefix) + 1)
    else
        return s
    end
end

--- Returns a string with the given prefix removed if it is found in the string
--- in the form `"file/path:line,col" -> "file/path", line, col`.
---
--- @param s string
--- @return string s, number|nil line, number|nil col
M.strip_line_col = function(s)
    local _, _, new_s, line, col = string.find(s, '^(.+):(%d+),(%d+)$', 1, false)
    if new_s == nil then
        return s
    else
        return new_s, tonumber(line), tonumber(col)
    end
end

--- Returns a new id for use in sending messages.
--- @return fun():number #Randomly generated id
M.next_id = (function()
    -- Ensure that we have something kind-of random
    math.randomseed(os.time())

    return function()
        return math.floor(math.random() * 10000)
    end
end)()

--- Returns the parent path of the given path, or nil if there is no parent.
--- @param path string
--- @return string|nil
M.parent_path = function(path)
    -- Pattern from https://stackoverflow.com/a/12191225/3164172
    local parent = string.match(path, '(.-)([^\\/]-%.?([^%.\\/]*))$')
    if parent ~= nil and parent ~= '' and parent ~= path then
        return parent
    end
end

--- Join multiple path components together, separating by `sep`.
--- @param sep string
--- @param paths string[]
--- @return string #The path as a string
M.join_path = function(sep, paths)
    assert(type(sep) == 'string', 'sep must be a string')
    assert(vim.tbl_islist(paths), 'paths must be a list')
    local path = ''

    for _, component in ipairs(paths) do
        -- If we already have a partial path, we need to add the separator
        if path ~= '' and not vim.endswith(path, sep) then
            path = path .. sep
        end

        path = path .. component
    end

    return path
end

--- Creates a new directory locally.
--- @param opts {path:string, parents?:boolean, mode?:number}
--- @param cb fun(err:string|nil)
M.mkdir = function(opts, cb)
    opts = opts or {}

    local path = opts.path
    local parents = opts.parents
    local mode = opts.mode or 448 -- 0o700

    cb = vim.schedule_wrap(cb)

    vim.loop.fs_stat(path, function(err, stat)
        local exists = not err and not (not stat)
        local is_dir = exists and stat ~= nil and stat.type == 'directory'
        local is_file = exists and stat ~= nil and stat.type == 'file'

        if is_dir then
            return cb(nil)
        elseif is_file then
            return cb(string.format('Cannot create dir: %s is file', path))
        else
            --- @diagnostic disable-next-line:redefined-local
            vim.loop.fs_mkdir(path, mode, function(err, success)
                if success then
                    return cb(nil)
                elseif parents then
                    local parent_path = M.parent_path(path)
                    if not parent_path then
                        return cb('Cannot create parent directory: reached top!')
                    end

                    -- If cannot create directory on its own, we try to
                    -- recursively create it until we succeed or fail
                    return M.mkdir({
                            path = parent_path,
                            parents = parents,
                            mode = mode
                        },
                        --- @diagnostic disable-next-line:unused-local
                        function(_err)
                            --- @diagnostic disable-next-line:redefined-local
                            vim.loop.fs_mkdir(path, mode, function(err, success)
                                if not err and not success then
                                    err = 'Something went wrong creating ' .. path
                                end
                                return cb(err)
                            end)
                        end)
                else
                    return cb(string.format('Cannot create dir: %s', err or '???'))
                end
            end)
        end
    end)
end

--- Applies a bitmask of either AND, OR, XOR.
--- From https://stackoverflow.com/a/32389020
--- @param a integer #number to be masked
--- @param b integer #mask
--- @param op 'or'|'xor'|'and'
--- @return integer
M.bitmask = function(a, b, op)
    --- @type number
    local oper
    if op == 'or' then
        oper = 1
    elseif op == 'xor' then
        oper = 3
    elseif op == 'and' then
        oper = 4
    else
        error('op must be any of "or", "xor", "and"')
    end

    local r, m = 0, 2 ^ 31
    local s = nil
    repeat
        s, a, b = a + b + m, a % m, b % m
        r, m = r + m * oper % (s - a - b), m / 2
    until m < 1
    return r
end

--- Produces a send/receive pair in the form of {tx, rx} where
--- tx is a function that sends a message and rx is a function that
--- waits for the message.
---
--- The `rx` function will throw an error if timed out, so make sure to
--- use `pcall` if you want to capture the error instead of throwing it.
---
--- @param timeout integer # Milliseconds that rx will wait
--- @param interval? integer # Milliseconds to wait inbetween checking for a message (default 200)
--- @return fun(...) tx, fun():...  rx #tx sends the value and rx receives the value
M.oneshot_channel = function(timeout, interval)
    vim.validate({
        timeout = { timeout, 'number' },
        interval = { interval, 'number', true },
    })

    -- 200 is the default for vim.wait interval, but we still want to be explicit
    if type(interval) ~= 'number' then
        interval = 200
    end

    -- Will store our result
    local data

    local tx = function(...)
        if data == nil then
            data = { ... }
        end
    end

    local rx = function()
        -- Wait for the result to be set, or time out
        local success, code = vim.wait(
            timeout,
            function() return data ~= nil end,
            interval
        )

        -- If we failed, report the error
        if not success then
            local timeout_str = tostring(timeout)
            if timeout > 1000 then
                timeout_str = string.format('%.2f', timeout)
            end
            if code == -1 then
                error('Timeout of ' .. timeout_str .. ' exceeded!')
            elseif code == -2 then
                error('Timeout of ' .. timeout_str .. ' interrupted!')
            end
        end

        -- Grab and clear our temporary variable if it is set and return it's value
        local result = data
        data = nil

        return unpack(result)
    end

    return tx, rx
end

--- Checks whether the object is callable, being a function or implementing __call.
--- @param x any
--- @return boolean
function M.callable(x)
    if type(x) == 'function' then
        return true
    elseif type(x) == 'table' then
        local mt = getmetatable(x)
        return type(mt) == 'table' and type(mt.__call) == 'function'
    else
        return false
    end
end

--- Use with `vim.validate` to check if a function or implements __call.
---
--- @param opts? {optional?:boolean}
--- @return fun(x:any):(boolean, string|nil)
function M.validate_callable(opts)
    local optional = (opts or {}).optional == true

    return function(x)
        local callable = M.callable(x)

        if type(x) == 'nil' and optional then
            callable = true
        end

        local msg
        if not callable then
            msg = vim.inspect(x) .. ' is not callable'
        end

        return callable, msg
    end
end

return M
