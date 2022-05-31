local log = require('distant.log')

local utils = {}

local PLUGIN_NAME = 'distant.nvim'

--- @return string
utils.plugin_name = function() return PLUGIN_NAME end

--- Represents the separator for use with local file system
---
--- From https://github.com/williamboman/nvim-lsp-installer/blob/main/lua/nvim-lsp-installer/path.lua
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
utils.seperator = function() return SEPARATOR end

--- Returns path to data directory for this plugin
--- @return string
utils.data_path = function()
    return (
        vim.fn.stdpath('data') ..
            utils.seperator() ..
            utils.plugin_name()
        )
end

--- @alias OperatingSystem 'windows'|'linux'|'macos'|'bsd'|'solaris'|'unknown'
--- @alias Architecture 'x86'|'x86_64'|'powerpc'|'arm'|'mips'|'unknown'

--- Original from https://gist.github.com/soulik/82e9d02a818ce12498d1
---
--- @return OperatingSystem, Architecture
utils.detect_os_arch = function()
    local raw_os_name, raw_arch_name = '', ''

    -- LuaJIT shortcut
    if jit and jit.os and jit.arch then
        raw_os_name = jit.os
        raw_arch_name = jit.arch
    else
        -- is popen supported?
        local popen_status, popen_result = pcall(io.popen, '')
        if popen_status then
            popen_result:close()
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

--- @class JobHandle
--- @field id function():string
--- @field write function(data):void
--- @field stop function():void

--- @class JobStartOpts
--- @field env? table<string, string> @a table of process environment variables
--- @field on_stdout_line fun(line:string) @a function that is triggered once per line of stdout
--- @field on_stderr_line fun(line:string) @a function that is triggered once per line of stderr
--- @field on_success? fun() @a function that is triggered with no arguments once the job finishes successfully
--- @field on_failure? fun(exit_code:number) @a function that is triggered with an exit code as the single argument once the job finishes unsuccessfully

--- Start an async job using the given cmd and options
---
--- @param cmd any
--- @param opts? JobStartOpts
--- @return JobHandle
utils.job_start = function(cmd, opts)
    --- @param cb fun(line:string)
    local function make_on_data(cb)
        local lines = { '' }
        return function(_, data, _)
            local send_back = function() end
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
        env = opts.env;
        on_stdout = make_on_data(opts.on_stdout_line);
        on_stderr = make_on_data(opts.on_stderr_line);
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
        end;
    })

    if job_id == 0 then
        log.fmt_error('Invalid arguments: %s', cmd)
    elseif job_id == -1 then
        log.fmt_error('Cmd is not executable: %s', cmd)
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
            end
        }
    end
end

--- Returns a string with the given prefix removed if it is found in the string
utils.strip_prefix = function(s, prefix)
    local offset = string.find(s, prefix, 1, true)
    if offset == 1 then
        return string.sub(s, string.len(prefix) + 1)
    else
        return s
    end
end

--- Maps and filters out nil elements in an array using the given function,
--- returning nil if given nil as the array
utils.filter_map = function(array, f)
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
utils.find = function(array, f)
    if array == nil then
        return nil
    end

    for _, v in ipairs(array) do
        if f(v) then
            return v
        end
    end
    return nil
end

--- Compresses a string by trimming whitespace on each line and replacing
--- newlines with a single space so that it can be sent as a single
--- line to command line interfaces while also ensuring that lines aren't
--- accidentally merged together
utils.compress = function(s)
    return utils.concat_nonempty(
        utils.filter_map(
            vim.split(s, '\n', true),
            (function(line)
                return vim.trim(line)
            end)
        ),
        ' '
    )
end

--- Concats an array using the provided separator, returning the resulting
--- string if non-empty, otherwise will return nil
utils.concat_nonempty = function(array, sep)
    if array and #array > 0 then
        return table.concat(array, sep)
    end
end

--- Returns true if the provided table contains the given value
utils.contains = function(tbl, value)
    for _, v in pairs(tbl) do
        if v == value then
            return true
        end
    end

    return false
end

--- Short wrapper to check if a specific global variable exists
utils.nvim_has_var = function(name)
    return vim.fn.exists('g:' .. name) == 1
end

--- Short wrapper to remove a global variable if it exists, returning its
--- value; if it does not exist, nil is returned
utils.nvim_remove_var = function(name)
    if not utils.nvim_has_var(name) then
        return nil
    end

    local value = vim.api.nvim_get_var(name)
    vim.api.nvim_del_var(name)

    return value
end

--- Returns a new id for use in sending messages
--- @return number id Randomly generated id
utils.next_id = function()
    return math.floor(math.random() * 10000)
end

--- Defines an augroup
--- From https://github.com/wincent/wincent
---
--- @param name string The name of the augroup
--- @param cb function The callback to invoke within the augroup definition
utils.augroup = function(name, cb)
    vim.cmd('augroup ' .. name)
    vim.cmd('autocmd!')
    cb()
    vim.cmd('augroup END')
end

--- Defines an autocmd (use within augroup)
--- From https://github.com/wincent/wincent
---
--- @param name string Name of the autocmd
--- @param pattern string Pattern for the autocmd
--- @param cmd function|string Either a callback to be triggered or a string
---        representing a vim expression
utils.autocmd = function(name, pattern, cmd)
    -- NOTE: Inlined here to avoid loop from circular dependencies
    local data = require('distant.data')

    local cmd_type = type(cmd)
    if cmd_type == 'function' then
        local id = data.insert(cmd)
        cmd = data.get_as_key_mapping(id)
    elseif cmd_type ~= 'string' then
        error('autocmd(): unsupported cmd type: ' .. cmd_type)
    end
    vim.cmd('autocmd ' .. name .. ' ' .. pattern .. ' ' .. cmd)
end

--- Produces a table of N lines all with the same text
---
--- @param n number The total number of lines to produce
--- @param line string The line to replicate
--- @return table lines The table of lines {'line', 'line', ...}
utils.make_n_lines = function(n, line)
    local lines = {}

    for _ = 1, n do
        table.insert(lines, line)
    end

    return lines
end

--- Reads all lines from a file
---
--- @param path string Path to the file
--- @return list|nil #List of lines split by newline, or nil if failed to read
utils.read_lines = function(path)
    local f = io.open(path, "rb")
    local contents = nil
    if f then
        contents = f:read(_VERSION <= "Lua 5.2" and "*a" or "a")
        f:close()
    end
    if contents ~= nil then
        return vim.split(contents, '\n', true)
    end
end

--- Reads all lines from a file and then removes the file
---
--- @param path string Path to the file
--- @return list|nil #List of lines split by newline, or nil if failed to read
utils.read_lines_and_remove = function(path)
    local lines = utils.read_lines(path)
    os.remove(path)
    return lines
end

--- Strips a string of ANSI escape sequences and carriage returns
---
--- @param text string The text to clean
--- @return string #The cleaned text
utils.clean_term_line = function(text)
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
utils.parent_path = function(path)
    -- Pattern from https://stackoverflow.com/a/12191225/3164172
    local parent = string.match(path, '(.-)([^\\/]-%.?([^%.\\/]*))$')
    if parent ~= nil and parent ~= '' and parent ~= path then
        return parent
    end
end

--- Join multiple path components together, separating by /
--- @return string #The path as a string
utils.join_path = function(...)
    local path = ''

    for _, component in ipairs({ ... }) do
        -- If we already have a partial path, we need to add the separator
        if path ~= '' and not vim.endswith(path, '/') then
            path = path .. '/'
        end

        path = path .. component
    end

    return path
end

--- Produces a send/receive pair in the form of {tx, rx} where
--- tx is a function that sends a message and rx is a function that
--- waits for the message
---
--- @param timeout number is the milliseconds that rx will wait
--- @param interval number is the milliseconds to wait inbetween checking for a message
--- @return fun(...) tx, fun():string|nil, ... rx #tx sends the value and rx receives the value
utils.oneshot_channel = function(timeout, interval)
    vim.validate({
        timeout = { timeout, 'number' },
        interval = { interval, 'number' },
    })

    -- Will store our result
    local data

    local tx = function(...)
        data = { ... }
    end

    local rx = function()
        -- Wait for the result to be set, or time out
        vim.wait(
            timeout,
            function() return data ~= nil end,
            interval
        )

        -- Grab and clear our temporary variable if it is set and return it's value
        local result = data
        data = nil

        -- Add our error to beginning of the result list
        if not vim.tbl_islist(result) then
            local err = 'Timeout of ' .. tostring(timeout) .. ' exceeded!'
            result = { err, result }

            -- Otherwise, add our error argument to the front
        else
            table.insert(result, 1, false)
        end

        return unpack(result)
    end

    return tx, rx
end

return utils
