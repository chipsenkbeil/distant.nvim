local utils = require('distant.utils')

local REPO_URL = 'https://github.com/chipsenkbeil/distant'
local RELEASE_API_ENDPOINT = 'https://api.github.com/repos/chipsenkbeil/distant/releases'
local MAX_DOWNLOAD_CHOICES = 5

--- Mapping of {os}:{arch} to artifact under releases
local PLATFORM_BIN = {
    ['windows:x86_64']      = 'distant-win64.exe',
    ['linux:x86_64']        = 'distant-linux64-gnu',
    ['linux:x86_64:musl']   = 'distant-linux64-musl',
    ['macos:x86_64']        = 'distant-macos',
    ['macos:arm']           = 'distant-macos',
}

--- Mapping of downloaded binary to name we want to use on system
local RENAME_BIN = {
    ['distant-win64.exe']       = 'distant.exe',
    ['distant-linux64-gnu']     = 'distant',
    ['distant-linux64-musl']    = 'distant',
    ['distant-macos']           = 'distant',
}

-- From https://stackoverflow.com/a/23535333/3164172
--
-- Returns /abs/path/to/distant/lib/
local function script_path()
    local str = debug.getinfo(2, "S").source:sub(2)
    return str:match("(.*[/\\])")
end

-- From https://github.com/nvim-lua/plenary.nvim/blob/master/lua/plenary/path.lua
local make_path_parent_fn = function(sep)
    local formatted = string.format("^(.+)%s[^%s]+", sep, sep)
    return function(abs_path)
        return abs_path:match(formatted)
    end
end

--- @class QueryReleaseApiOpts
--- @field page? number #Page in release list to query, defaulting to first page
--- @field per_page? number #Number of entries to query for a page

--- @param opts QueryReleaseApiOpts
--- @param cb fun(success:boolean, result:string|table)
--- @return number #job-id on success, 0 on invalid arguments, -1 if unable to execute cmd
local function query_release_api(opts, cb)
    if not cb then
        cb = opts
        opts = {}
    end
    vim.validate({opts = {opts, 'table'}, cb = {cb, 'function'}})

    -- Build our query string of ?page=N&per_page=N
    local query = ''
    if type(opts.page) == 'number' then
        query = query .. 'page=' .. tostring(opts.page)
    end
    if type(opts.per_page) == 'number' then
        if #query > 0 then
            query = query .. '&'
        end
        query = query .. 'per_page=' .. tostring(opts.per_page)
    end
    if #query > 0 then
        query = '?' .. query
    end

    local endpoint = RELEASE_API_ENDPOINT .. query

    local cmd
    if tonumber(vim.fn.executable('curl')) == 1 then
        cmd = string.format('curl -fL %s', endpoint)
    elseif tonumber(vim.fn.executable('wget')) == 1 then
        cmd = string.format('wget -q -O - %s', endpoint)
    elseif tonumber(vim.fn.executable('fetch')) == 1 then
        cmd = string.format('fetch -q -o - %s', endpoint)
    end

    if not cmd then
        return cb(false, 'No external command is available. Please install curl, wget, or fetch!')
    end

    local json_str, err
    return vim.fn.jobstart(cmd, {
        on_exit = function(_, exit_code)
            if exit_code ~= 0 then
                cb(false, 'Exit ' .. tostring(exit_code) .. ': ' .. tostring(err))
            else
                cb(pcall(vim.fn.json_decode, json_str or ''))
            end
        end,
        on_stdout = function(_, data, _)
            json_str = table.concat(data)
        end,
        on_stderr = function(_, data, _)
            err = table.concat(data)
        end,
        stdout_buffered = true,
        stderr_buffered = true,
    })
end

--- @class QueryReleaseListOpts
--- @field asset_name string #Name of the asset to look for in the release list
--- @field page? number #Page in release list to query, defaulting to first page
--- @field per_page? number #Number of entries to query for a page

--- @class ReleaseEntry
--- @field url string
--- @field tag string
--- @field description string
--- @field draft boolean
--- @field prerelease boolean

--- Retrieve some subset of release entries
--- @param opts QueryReleaseListOpts
--- @param cb fun(success:boolean, res:string|ReleaseEntry[])
--- @return number #job-id on success, 0 on invalid arguments, -1 if unable to execute cmd
local function query_release_list(opts, cb)
    if not cb then
        cb = opts
        opts = {}
    end
    vim.validate({opts = {opts, 'table'}, cb = {cb, 'function'}})
    if type(opts.asset_name) ~= 'string' then
        error('opts.asset_name is required and must be a string')
    end

    return query_release_api(opts, function(success, res)
        if not success then
            return cb(success, res)
        end

        --- @type ReleaseEntry[]
        local entries = {}
        for _, item in ipairs(res) do
            local entry = {
                tag = item.tag_name,
                draft = item.draft,
                prerelease = item.prerelease,
            }

            -- Find the url to use to download the asset
            for _, asset in ipairs(item.assets or {}) do
                if asset.name == opts.asset_name then
                    entry.url = asset.browser_download_url
                    break
                end
            end

            -- Only add the entry if we have an appropriate asset
            -- and a tag associated with it
            if entry.url and entry.tag then
                local attrs = {}
                if entry.draft then
                    table.insert(attrs, 'draft')
                end
                if entry.prerelease then
                    table.insert(attrs, 'prerelease')
                end

                entry.description = entry.tag
                if #attrs > 0 then
                    entry.description = string.format(
                        '%s (%s)', entry.description, table.concat(attrs, ',')
                    )
                end

                table.insert(entries, entry)
            end
        end

        cb(true, entries)
    end)
end

--- Downloads src using curl, wget, or fetch and stores it at dst
--- @param src string
--- @param dst string
--- @param cb fun(success:boolean, err:string|nil)
--- @return number #job-id on success, 0 on invalid arguments, -1 if unable to execute cmd
local function download(src, dst, cb)
    local cmd
    if tonumber(vim.fn.executable('curl')) == 1 then
        cmd = string.format('curl -fLo %s --create-dirs %s', dst, src)
    elseif tonumber(vim.fn.executable('wget')) == 1 then
        cmd = string.format('wget -O %s %s', dst, src)
    elseif tonumber(vim.fn.executable('fetch')) == 1 then
        cmd = string.format('fetch -o %s %s', dst, src)
    end

    if not cmd then
        return cb(false, 'No external command is available. Please install curl, wget, or fetch!')
    end

    -- Create a new buffer to house our terminal window
    local bufnr = vim.api.nvim_create_buf(false, true)
    assert(bufnr ~= 0, 'Failed to create buffer')
    vim.api.nvim_win_set_buf(0, bufnr)

    return vim.fn.termopen(cmd, {
        pty = true,
        on_exit = function(_, exit_code)
            if exit_code ~= 0 then
                vim.schedule(function()
                    cb(false, string.format('%s failed (%s)', cmd, exit_code))
                end)
            else
                -- Close out the terminal window
                vim.api.nvim_buf_delete(bufnr, {force = true})

                vim.schedule(function()
                    cb(true)
                end)
            end
        end
    })
end

--- @alias OperatingSystem 'windows'|'linux'|'macos'|'bsd'|'solaris'|'unknown'
--- @alias Architecture 'x86'|'x86_64'|'powerpc'|'arm'|'mips'|'unknown'

--- Original from https://gist.github.com/soulik/82e9d02a818ce12498d1
---
--- @return OperatingSystem, Architecture
local function detect_os_arch()
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
            raw_os_name = io.popen('uname -s','r'):read('*l')
            raw_arch_name = io.popen('uname -m','r'):read('*l')
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

--- @class PromptChoicesOpts
--- @field prompt string
--- @field choices string[]
--- @field max_choices? number

--- @param opts PromptChoicesOpts
--- @return number|nil #Index of choice selected, or nil if quit
local function prompt_choices(opts)
    vim.validate({opts = {opts, 'table'}})
    local prompt = opts.prompt
    local choices = opts.choices
    local max_choices = opts.max_choices or 999

    local choices_list = {{}}
    for i, choice in ipairs(choices) do
        -- If current selection is maxed out in size, start a new one
        if #choices_list[#choices_list] == max_choices then
            table.insert(choices_list, {})
        end

        table.insert(
            choices_list[#choices_list],
            string.format('%s. %s', ((i - 1) % max_choices) + 1, choice)
        )
    end

    for i, args in ipairs(choices_list) do
        local not_last = i < #choices_list
        local size = #args
        table.insert(args, 1, prompt)
        if not_last then
            table.insert(args, tostring(max_choices + 1) .. '. [Show me more]')
        end

        local choice = vim.fn.inputlist(args)
        if choice > 0 and choice <= size then
            return choice + (max_choices * (i - 1))
        elseif choice == size + 1 and not_last then
            -- Continue our loop with the next set
        else
            break
        end
    end
end

-- Constants
local HOST_OS, HOST_ARCH = detect_os_arch()
local HOST_PLATFORM = HOST_OS .. ':' .. HOST_ARCH
local SEP = utils.seperator()
local ROOT_DIR = (function()
    -- script_path -> /path/to/lua/distant/
    -- up -> /path/to/lua
    local get_parent_path = make_path_parent_fn(SEP)
    return get_parent_path(script_path())
end)()

local function bin_path(opts)
    return utils.data_path()
end

-- From https://www.lua.org/pil/19.3.html
local function pair_by_keys(t, f)
    local a = {}
    for n in pairs(t) do table.insert(a, n) end
    table.sort(a, f)
    local i = 0
    local iter = function()
        i = i + 1
        if a[i] == nil then return nil
        else return a[i], t[a[i]]
        end
    end
    return iter
end

--- @param bin_name? string #Name of binary artifact to download, defaulting to platform choice
--- @param cb fun(success:boolean, err:string|nil)
--- @return number #job-id on success, 0 on invalid arguments, -1 if unable to execute cmd
local function download_binary(bin_name, cb)
    if not cb then
        cb = bin_name
        bin_name = nil
    end

    bin_name = bin_name or PLATFORM_BIN[HOST_PLATFORM]

    if not bin_name then
        local choices = {}
        local libs = {}
        for platform, platform_bin in pair_by_keys(PLATFORM_BIN) do
            table.insert(choices, platform)
            table.insert(libs, platform_bin)
        end
        local idx = prompt_choices({
            prompt = string.format('\nUnknown platform %s! Please select from the following:', HOST_PLATFORM),
            choices = choices,
        })
        if idx then
            bin_name = libs[idx]
        end
    end

    if not bin_name then
        return cb(false, 'No binary available for ' .. HOST_PLATFORM)
    end

    return query_release_list({asset_name = bin_name}, function(success, res)
        if not success then
            return cb(success, res)
        end

        local choices = vim.tbl_map(function(entry) return entry.description end, res)
        local choice = prompt_choices({
            prompt = 'Which version of the binary do you want?',
            choices = choices,
            max_choices = MAX_DOWNLOAD_CHOICES,
        })
        local entry = res[choice]
        if not entry then
            return cb(false, 'Cancelled selecting binary version')
        end

        local dst = ROOT_DIR
        if vim.endswith(bin_name, 'dll') then
            dst = dst .. SEP .. bin_name .. '.dll'
        else
            dst = dst .. SEP .. bin_name .. '.so'
        end

        return download(entry.url, dst, cb)
    end)
end

--- @param path? string
--- @param cb fun(success:boolean, err:string|nil)
local function copy_binary(path, cb)
    if not cb then
        cb = path
        path = nil
    end

    if not path then
        local ext
        if HOST_OS == 'windows' then
            ext = 'dll'
        elseif HOST_OS == 'macos' then
            ext = 'dylib'
        else
            ext = 'so'
        end
        path = vim.fn.input('Path to "' .. ext .. '": ')
    end

    if path and #path > 0 then
        local dst = ROOT_DIR
        if vim.endswith(path, 'dll') then
            dst = dst .. SEP .. bin_name .. '.dll'
        else
            dst = dst .. SEP .. bin_name .. '.so'
        end

        vim.loop.fs_copyfile(path, dst, function(err, success)
            vim.schedule(function()
                if err then
                    cb(false, err)
                elseif not success then
                    cb(false, 'Failed to copy ' .. path .. ' to ' .. dst)
                else
                    cb(true)
                end
            end)
        end)
    else
        cb(false, 'binary path missing')
    end
end

--- @param cb fun(success:boolean, result:string)
--- @return number #job-id on success, 0 on invalid arguments, -1 if unable to execute cmd
local function clone_repository(cb)
    if tonumber(vim.fn.executable('git')) ~= 1 then
        return cb(false, 'git not found in path')
    end

    local tmpdir = vim.fn.tempname()
    local cmd = string.format('git clone --depth 1 %s %s', REPO_URL, tmpdir)

    -- Create a new buffer to house our terminal window
    local bufnr = vim.api.nvim_create_buf(false, true)
    assert(bufnr ~= 0, 'Failed to create buffer')
    vim.api.nvim_win_set_buf(0, bufnr)

    return vim.fn.termopen(cmd, {
        pty = true,
        on_exit = function(_, exit_code)
            if exit_code ~= 0 then
                vim.fn.delete(tmpdir, 'rf')
                vim.schedule(function()
                    cb(false, string.format('%s failed (%s)', cmd, exit_code))
                end)
            else
                -- Close out the terminal window
                vim.api.nvim_buf_delete(bufnr, {force = true})

                vim.schedule(function()
                    cb(true, tmpdir)
                end)
            end
        end
    })
end

--- @param cb fun(success:boolean, err:string|nil)
--- @return number #job-id on success, 0 on invalid arguments, -1 if unable to execute cmd
local function build_binary(cb)
    return clone_repository(function(success, tmpdir)
        if not success then
            return vim.schedule(function()
                cb(success, tmpdir)
            end)
        end

        if tonumber(vim.fn.executable('cargo')) ~= 1 then
            return cb(false, 'cargo not found in path')
        end

        -- Create a new buffer to house our terminal window
        local bufnr = vim.api.nvim_create_buf(false, true)
        assert(bufnr ~= 0, 'Failed to create buffer')
        vim.api.nvim_win_set_buf(0, bufnr)

        local cargo_toml = tmpdir .. SEP .. 'distant-lua' .. SEP .. 'Cargo.toml'
        local release_lib = tmpdir .. SEP .. 'target' .. SEP .. 'release' .. SEP
        if HOST_OS == 'windows' then
            release_lib = release_lib .. bin_name .. '.dll'
        elseif HOST_OS == 'macos' then
            release_lib = release_lib .. 'lib' .. bin_name .. '.dylib'
        else
            release_lib = release_lib .. 'lib' .. bin_name .. '.so'
        end

        -- Build release binary
        local cmd = string.format('cargo build --release', cargo_toml)
        return vim.fn.termopen(cmd, {
            cwd = tmpdir .. SEP .. 'distant-lua',
            pty = true,
            on_exit = function(_, exit_code)
                if exit_code ~= 0 then
                    vim.fn.delete(tmpdir, 'rf')
                    vim.schedule(function()
                        cb(false, string.format('%s failed (%s)', cmd, exit_code))
                    end)
                else
                    -- Close out the terminal window
                    vim.api.nvim_buf_delete(bufnr, {force = true})

                    vim.schedule(function()
                        copy_binary(release_lib, function(status, msg)
                            vim.fn.delete(tmpdir, 'rf')
                            cb(status, msg)
                        end)
                    end)
                end
            end
        })
    end)
end

--- Get the binary if it is available, otherwise returns nil
local function get()
    local success, lib = pcall(require, bin_name)
    if success then
        return lib
    end
end

--- Returns true if the binary is loaded, otherwise return false
local function is_loaded()
    return package.loaded[bin_name] ~= nil
end

--- Returns object with loaded (bool) and errors (list of err strings)
--- when attempting to a load a binary
---
--- From https://stackoverflow.com/a/15434737
local function try_load_lib(name)
    local errors = {}

    if package.loaded[name] then
        return { loaded = true, errors = errors }
    else
        for _, searcher in ipairs(package.searchers or package.loaders) do
            local success, loader = pcall(searcher, name)
            if success then
                if type(loader) == 'function' then
                    package.preload[name] = loader
                    return { loaded = true, errors = errors }
                end
            else
                table.insert(errors, tostring(loader))
            end
        end
        return { loaded = false, errors = errors }
    end
end

--- Loads the binary asynchronously, providing several options to install the binary
--- if it is unavailable
---
--- An option of `reload` can be provided to force prompts and remove any loaded instance
--- of the binary.
---
--- @param opts table
--- @param cb function (bool, lib|err) where bool = true on success and lib would be second arg
local function load(opts, cb)
    local lib_status, err_msg

    if not cb then
        cb = opts
        opts = {}
    end
    vim.validate({
        opts={opts, 'table'},
        cb={cb, 'function'},
    })
    opts.reload = not (not opts.reload)

    -- If not reloading the binary
    if not opts.reload then
        lib_status = try_load_lib(bin_name)
        if not lib_status.loaded and not vim.tbl_isempty(lib_status.errors) then
            err_msg = ''
            for _, err in ipairs(lib_status.errors) do
                err_msg = err_msg .. err
            end
            return cb(false, err_msg)
        end

        local success, lib = pcall(require, bin_name)
        if success then
            return cb(success, lib)
        end

    -- If reloading the binary, clear it out
    else
        package.loaded[bin_name] = nil
    end

    local prompt = opts.reload and
        'Reloading Rust binary! What would you like to do?' or
        'Rust binary not found! What would you like to do?'

    local choice = prompt_choices({
        prompt = prompt,
        choices = {
            'Download a prebuilt lib',
            'Build from source',
            'Copy local lib',
        },
    })

    if not choice then
        return cb(false, 'Aborted choice prompt')
    end

    local on_installed = function(status, msg)
        if not status then
            return cb(status, msg)
        end

        lib_status = try_load_lib(bin_name)
        if not lib_status.loaded and not vim.tbl_isempty(lib_status.errors) then
            err_msg = ''
            for _, err in ipairs(lib_status.errors) do
                err_msg = err_msg .. err
            end
            return cb(false, err_msg)
        end

        return cb(pcall(require, bin_name))
    end

    if choice == 1 then
        return download_binary(on_installed)
    elseif choice == 2 then
        return build_binary(on_installed)
    elseif choice == 3 then
        return copy_binary(on_installed)
    end
end

return {
    get = get,
    is_loaded = is_loaded,
    load = load,
}
