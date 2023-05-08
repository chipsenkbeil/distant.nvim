local log = require('distant-core.log')

--- @class distant.core.Utils
local M = {}

local PLUGIN_NAME = 'distant.nvim'

--- @return string
M.plugin_name = function() return PLUGIN_NAME end

--- Represents the separator for use with local file system
---
--- From https://github.com/williamboman/nvim-lsp-installer/blob/main/lua/nvim-lsp-installer/path.lua
---
--- @type '\\'|'/'
local SEPARATOR = (function()
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

--- @return string
M.seperator = function() return SEPARATOR end

--- Returns path to cache directory for this plugin
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

--- Returns path to data directory for this plugin
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

--- @alias distant.core.utils.OperatingSystem 'windows'|'linux'|'macos'|'bsd'|'solaris'|'unknown'
--- @alias distant.core.utils.Architecture 'x86'|'x86_64'|'powerpc'|'arm'|'mips'|'unknown'

--- Original from https://gist.github.com/soulik/82e9d02a818ce12498d1
---
--- @return distant.core.utils.OperatingSystem, distant.core.utils.Architecture
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
    return os_name, arch_name
end

--- @class distant.core.utils.JobHandle
--- @field id function():string
--- @field write function(data):void
--- @field stop function():void
--- @field running function():boolean

--- @class distant.core.utils.JobStartOpts
--- @field env? table<string, string> @a table of process environment variables
--- @field on_stdout_line fun(line:string) @a function that is triggered once per line of stdout
--- @field on_stderr_line fun(line:string) @a function that is triggered once per line of stderr
--- @field on_success? fun() @a function that is triggered with no arguments once the job finishes successfully
--- @field on_failure? fun(exit_code:number) @a function that is triggered with an exit code as the single argument once the job finishes unsuccessfully

--- Start an async job using the given cmd and options
---
--- @param cmd any
--- @param opts? distant.core.utils.JobStartOpts
--- @return distant.core.utils.JobHandle
M.job_start = function(cmd, opts)
    opts = opts or {}

    --- @param cb fun(line:string)
    local function make_on_data(cb)
        local lines = { '' }
        return function(_, data, _)
            local send_back = function()
            end
            if type(cb) == 'function' then
                send_back = function(line)
                    if line ~= '' then
                        cb(line)
                    end
                end
            end

            -- Build up our lines by adding any partial line data to the current
            -- partial line, and then treating all additional data as extra lines,
            -- keeping in mind that the final line is also partial
            lines[#lines] = lines[#lines] .. data[1]
            for i, line in ipairs(data) do
                if i > 1 then
                    table.insert(lines, line)
                end
            end

            -- End of stream, so write whatever we have in our buffer
            if #data == 1 and data[1] == '' then
                send_back(lines[1])

                -- Otherwise, we want to report all of our lines except the last one
                -- which may be partial
            else
                for i, v in ipairs(lines) do
                    if i < #data then
                        send_back(v)
                    end
                end

                -- Remove all lines but the last one
                lines = { lines[#lines] }
            end
        end
    end

    local job_id = vim.fn.jobstart(cmd, {
        env = opts.env,
        on_stdout = make_on_data(opts.on_stdout_line),
        on_stderr = make_on_data(opts.on_stderr_line),
        on_exit = function(_, exit_code)
            if exit_code == 0 then
                if type(opts.on_success) == 'function' then
                    opts.on_success()
                end
            else
                if type(opts.on_failure) == 'function' then
                    opts.on_failure(exit_code)
                end
            end
        end,
    })

    if job_id == 0 then
        log.fmt_error('Invalid arguments: %s', cmd)
        error('Invalid arguments: ' .. tostring(cmd))
    elseif job_id == -1 then
        log.fmt_error('Cmd is not executable: %s', cmd)
        error('Cmd is not executable: ' .. tostring(cmd))
    else
        return {
            id = function()
                return job_id
            end,
            write = function(data)
                vim.fn.chansend(job_id, data)
            end,
            stop = function()
                vim.fn.jobstop(job_id)
            end,
            running = function()
                return vim.fn.jobwait({ job_id }, 0)[1] == -1
            end,
        }
    end
end

--- Returns a string with the given prefix removed if it is found in the string
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
--- in the form "file/path:line,col" -> "file/path", line, col
---
--- @param s string
--- @return string, number|nil, number|nil
M.strip_line_col = function(s)
    local _, _, new_s, line, col = string.find(s, '^(.+):(%d+),(%d+)$', 1, false)
    if new_s == nil then
        return s
    else
        return new_s, tonumber(line), tonumber(col)
    end
end

--- Maps and filters out nil elements in an array using the given function,
--- returning nil if given nil as the array
M.filter_map = function(array, f)
    if array == nil then
        return nil
    end

    local new_array = {}
    for _, v in ipairs(array) do
        local el = f(v)
        if el then
            table.insert(new_array, el)
        end
    end
    return new_array
end

--- Returns the first value where the predicate returns true, otherwise returns nil
--- @generic T
--- @param array T[]
--- @param f fun(x:T):boolean
--- @return T|nil
M.find = function(array, f)
    for _, v in ipairs(array) do
        if f(v) then
            return v
        end
    end
end

--- Compresses a string by trimming whitespace on each line and replacing
--- newlines with a single space so that it can be sent as a single
--- line to command line interfaces while also ensuring that lines aren't
--- accidentally merged together
M.compress = function(s)
    return M.concat_nonempty(
        M.filter_map(
            vim.split(s, '\n', { plain = true }),
            (function(line)
                return vim.trim(line)
            end)
        ),
        ' '
    )
end

--- Concats an array using the provided separator, returning the resulting
--- string if non-empty, otherwise will return nil
M.concat_nonempty = function(array, sep)
    if array and #array > 0 then
        return table.concat(array, sep)
    end
end

--- Returns true if the provided table contains the given value
M.contains = function(tbl, value)
    for _, v in pairs(tbl) do
        if v == value then
            return true
        end
    end

    return false
end

--- Returns a new id for use in sending messages
--- @return fun():number #Randomly generated id
M.next_id = (function()
    -- Ensure that we have something kind-of random
    math.randomseed(os.time())

    return function()
        return math.floor(math.random() * 10000)
    end
end)()

--- Produces a table of N lines all with the same text
---
--- @param n number The total number of lines to produce
--- @param line string The line to replicate
--- @return table lines The table of lines {'line', 'line', ...}
M.make_n_lines = function(n, line)
    local lines = {}

    for _ = 1, n do
        table.insert(lines, line)
    end

    return lines
end

--- Reads all lines from a file
---
--- @param path string Path to the file
--- @return string[]|nil #List of lines split by newline, or nil if failed to read
M.read_lines = function(path)
    local f = io.open(path, "rb")
    local contents = nil
    if f then
        contents = f:read(_VERSION <= "Lua 5.2" and "*a" or "a")
        f:close()
    end
    if contents ~= nil then
        return vim.split(contents, '\n', { plain = true })
    end
end

--- Reads all lines from a file and then removes the file
---
--- @param path string Path to the file
--- @return string[]|nil #List of lines split by newline, or nil if failed to read
M.read_lines_and_remove = function(path)
    local lines = M.read_lines(path)
    os.remove(path)
    return lines
end

--- Strips a string of ANSI escape sequences and carriage returns
---
--- @param text string The text to clean
--- @return string #The cleaned text
M.clean_term_line = function(text)
    local function strip_seq(s, p)
        s = string.gsub(s, '%c%[' .. p .. 'm', '')
        s = string.gsub(s, '%c%[' .. p .. 'K', '')
        return s
    end

    text = strip_seq(text, '%d%d?')
    text = strip_seq(text, '%d%d?;%d%d?')
    text = strip_seq(text, '%d%d?;%d%d?;%d%d?')
    text = string.gsub(text, '\r', '')
    return text
end

--- Returns the parent path of the given path, or nil if there is no parent
--- @param path string
--- @return string|nil
M.parent_path = function(path)
    -- Pattern from https://stackoverflow.com/a/12191225/3164172
    local parent = string.match(path, '(.-)([^\\/]-%.?([^%.\\/]*))$')
    if parent ~= nil and parent ~= '' and parent ~= path then
        return parent
    end
end

--- Join multiple path components together, separating by /
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
--- @param timeout number is the milliseconds that rx will wait
--- @param interval number is the milliseconds to wait inbetween checking for a message
--- @return fun(...) tx, fun():...  rx #tx sends the value and rx receives the value
M.oneshot_channel = function(timeout, interval)
    vim.validate({
        timeout = { timeout, 'number' },
        interval = { interval, 'number' },
    })

    -- Will store our result
    local data

    local tx = function(...)
        if data == nil then
            data = { ... }
        end
    end

    local rx = function()
        -- Wait for the result to be set, or time out
        local success = vim.wait(
            timeout,
            function() return data ~= nil end,
            interval
        )

        -- If we failed, report the error
        if not success then
            error('Timeout of ' .. tostring(timeout) .. ' exceeded!')
        end

        -- Grab and clear our temporary variable if it is set and return it's value
        local result = data
        data = nil

        return unpack(result)
    end

    return tx, rx
end

--- @param s string #json string
--- @param key string #key whose value to retrieve
--- @return string|nil #value of key if exists
M.parse_json_str_for_value = function(s, key)
    s = vim.trim(s)

    -- Ensure is an object string
    if not vim.startswith(s, '{') or not vim.endswith(s, '}') then
        return
    end

    -- Look for each match of key in json
    local indexes = {}
    local i = 0
    while true do
        i = string.find(s, key, i + 1)
        if i == nil then break end
        table.insert(indexes, i)
    end

    local char_at = function(str, idx) return str:sub(idx, idx) end

    -- We expect a quote to follow immediately after key,
    -- then at some point a colon (spaces are allowed),
    -- and then the value
    local c, value
    for _, idx in ipairs(indexes) do
        -- Get position after key
        i = idx + #key
        c = char_at(s, i)

        -- If next character is a quote, we assume this is a key
        if c == '"' then
            value = ''

            -- Now, skip ahead to the colon
            while c ~= ':' do
                i = i + 1
                c = char_at(s, i)
            end

            -- Now skip the colon
            i = i + 1
            c = char_at(s, i)

            -- Now capture everything until the next key or end of json
            while c ~= ',' and c ~= '}' do
                -- Add the current character and move past it
                value = value .. c
                i = i + 1

                -- Character was a quote - entering a quoted value - so read everything until the end quote
                if c == '"' then
                    local old_c = c

                    -- Update our referenced character to the next one
                    c = char_at(s, i)

                    -- Read while we don't have an unescaped double quote, read and add each character to value
                    while true do
                        -- If our current character is not an escaped quote, keep reading,
                        -- but if we run out of characters then exit
                        if old_c ~= '\\' and (c == '"' or c == nil) then
                            break
                        end

                        value = value .. c
                        i = i + 1
                        c = char_at(s, i)
                    end
                end

                -- Update our referenced character to the next one
                c = char_at(s, i)
            end

            -- Finally, trim our value to remove whitespace
            return vim.trim(value)
        end
    end
end

return M
