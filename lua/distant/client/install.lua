local utils = require('distant.utils')

-------------------------------------------------------------------------------
-- CONFIGURATION DEFAULTS
-------------------------------------------------------------------------------

local REPO_URL             = 'https://github.com/chipsenkbeil/distant'
local RELEASE_API_ENDPOINT = 'https://api.github.com/repos/chipsenkbeil/distant/releases'
local MAX_DOWNLOAD_CHOICES = 5

-------------------------------------------------------------------------------
-- MAPPINGS
-------------------------------------------------------------------------------

--- Mapping of {os}:{arch} to artifact under releases
local PLATFORM_BIN = {
    ['windows:x86_64']    = 'distant-win64.exe',
    ['linux:x86_64:gnu']  = 'distant-linux64-gnu',
    ['linux:x86_64:musl'] = 'distant-linux64-musl',
    ['macos:x86_64']      = 'distant-macos',
    ['macos:arm']         = 'distant-macos',
}

--- Mapping of type to local binary name we expect
local BIN_NAME = {
    WINDOWS = 'distant.exe',
    UNIX    = 'distant',
}

-------------------------------------------------------------------------------
-- INTERNAL GITHUB API
-------------------------------------------------------------------------------

--- @class QueryReleaseApiOpts
--- @field page? number #Page in release list to query, defaulting to first page
--- @field per_page? number #Number of entries to query for a page

--- @overload fun(cb:fun(success:boolean, result:string|table)):number
--- @param opts QueryReleaseApiOpts
--- @param cb fun(success:boolean, result:string|table)
--- @return number #job-id on success, 0 on invalid arguments, -1 if unable to execute cmd
local function query_release_api(opts, cb)
    if not cb then
        cb = opts
        opts = {}
    end
    vim.validate({ opts = { opts, 'table' }, cb = { cb, 'function' } })

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
--- @overload fun(cb:fun(success:boolean, res:string|ReleaseEntry[])):number
--- @param opts QueryReleaseListOpts
--- @param cb fun(success:boolean, res:string|ReleaseEntry[])
--- @return number #job-id on success, 0 on invalid arguments, -1 if unable to execute cmd
local function query_release_list(opts, cb)
    if not cb then
        cb = opts
        opts = {}
    end
    vim.validate({ opts = { opts, 'table' }, cb = { cb, 'function' } })
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
--- @param src string #url to download from
--- @param dst string #destination to store artifact
--- @param cb fun(success:boolean, result:string) #where result is an error message or the binary path
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
                vim.api.nvim_buf_delete(bufnr, { force = true })

                vim.schedule(function()
                    cb(true, dst)
                end)
            end
        end
    })
end

--- @class PromptChoicesOpts
--- @field prompt string
--- @field choices string[]
--- @field max_choices? number

--- @param opts PromptChoicesOpts
--- @return number|nil #Index of choice selected, or nil if quit
local function prompt_choices(opts)
    vim.validate({ opts = { opts, 'table' } })
    local prompt = opts.prompt
    local choices = opts.choices
    local max_choices = opts.max_choices or 999

    local choices_list = { {} }
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

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local HOST_OS, HOST_ARCH = utils.detect_os_arch()
local HOST_PLATFORM = HOST_OS .. ':' .. HOST_ARCH
local SEP = utils.seperator()

--- Represents the binary name to use based on the host operating system
local HOST_BIN_NAME = (function()
    if HOST_OS == 'windows' then
        return BIN_NAME.WINDOWS
    else
        return BIN_NAME.UNIX
    end
end)()

--- @return string #Path to local binary
local function bin_path()
    return utils.data_path() .. SEP .. 'bin' .. SEP .. HOST_BIN_NAME
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

-------------------------------------------------------------------------------
-- INSTALL HELPERS
-------------------------------------------------------------------------------

--- @overload fun(cb:fun(success:boolean, result:string)):number
--- @param bin_name string #Name of binary artifact to download, defaulting to platform choice
--- @param cb fun(success:boolean, result:string) #where result is an error message or the binary path
--- @return number #job-id on success, 0 on invalid arguments, -1 if unable to execute cmd
local function download_binary(bin_name, cb)
    --- @type string
    local host_platform = HOST_PLATFORM

    if not cb then
        cb = bin_name
        bin_name = nil
    end

    -- If using linux and we don't have a bin_name, adjust our host platform
    -- based on if they want gnu or musl
    if HOST_OS == 'linux' then
        local choices = { 'gnu', 'musl' }
        local idx = prompt_choices({
            prompt = string.format('\nLinux detected! Please select from the following libc options:'),
            choices = choices,
        })
        if idx then
            host_platform = host_platform .. ':' .. choices[idx]
        end
    end

    bin_name = bin_name or PLATFORM_BIN[host_platform]

    if not bin_name then
        local choices = {}
        local bins = {}
        for platform, platform_bin in pair_by_keys(PLATFORM_BIN) do
            table.insert(choices, platform)
            table.insert(bins, platform_bin)
        end
        local idx = prompt_choices({
            prompt = string.format('\nUnknown platform %s! Please select from the following:', host_platform),
            choices = choices,
        })
        if idx then
            bin_name = bins[idx]
        end
    end

    if not bin_name then
        return cb(false, 'No binary available for ' .. host_platform)
    end

    return query_release_list({ asset_name = bin_name }, function(success, res)
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

        return download(entry.url, bin_path(), cb)
    end)
end

--- @overload fun(cb:fun(success:boolean, result:string))
--- @param path string
--- @param cb fun(success:boolean, result:string) #where result is an error message or the binary path
local function copy_binary(path, cb)
    if not cb then
        cb = path
        path = nil
    end

    if not path then
        path = vim.fn.input('Path to binary: ')
    end

    if path and #path > 0 then
        local dst = bin_path()
        vim.loop.fs_copyfile(path, dst, function(err, success)
            vim.schedule(function()
                if err then
                    cb(false, err)
                elseif not success then
                    cb(false, 'Failed to copy ' .. path .. ' to ' .. dst)
                else
                    cb(true, dst)
                end
            end)
        end)
    else
        cb(false, 'Binary path missing')
    end
end

--- @param cb fun(success:boolean, result:string) #where result is an error message or the repo path
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
                vim.api.nvim_buf_delete(bufnr, { force = true })

                vim.schedule(function()
                    cb(true, tmpdir)
                end)
            end
        end
    })
end

--- @class BuildBinaryOpts
--- @field bin string

--- @overload fun(cb:fun(success:boolean, result:string)):number
--- @param opts BuildBinaryOpts
--- @param cb fun(success:boolean, result:string) #where result is an error message or the binary path
--- @return number #job-id on success, 0 on invalid arguments, -1 if unable to execute cmd
local function build_binary(opts, cb)
    if not cb then
        cb = opts
        opts = {}
    end

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

        -- $ROOT/distant/Cargo.toml
        local cargo_toml = tmpdir .. SEP .. 'Cargo.toml'

        -- $ROOT/distant/target/release/{bin}
        local release_bin = tmpdir .. SEP .. 'target' .. SEP .. 'release' .. SEP
        if HOST_OS == 'windows' then
            release_bin = release_bin .. 'distant.exe'
        else
            release_bin = release_bin .. 'distant'
        end

        -- Build release binary
        local cmd = string.format('cargo build --release', cargo_toml)
        return vim.fn.termopen(cmd, {
            cwd = tmpdir,
            pty = true,
            on_exit = function(_, exit_code)
                if exit_code ~= 0 then
                    vim.fn.delete(tmpdir, 'rf')
                    vim.schedule(function()
                        cb(false, string.format('%s failed (%s)', cmd, exit_code))
                    end)
                else
                    -- Close out the terminal window
                    vim.api.nvim_buf_delete(bufnr, { force = true })

                    vim.schedule(function()
                        copy_binary(release_bin, function(status, msg)
                            vim.fn.delete(tmpdir, 'rf')
                            cb(status, msg or release_bin)
                        end)
                    end)
                end
            end
        })
    end)
end

-------------------------------------------------------------------------------
-- PUBLIC API
-------------------------------------------------------------------------------

--- Returns true if the binary is loaded, otherwise return false
--- @return boolean
local function exists()
    return vim.fn.executable(bin_path()) == 1
end

--- Returns true if the binary is available on our path, even if not locally
--- @return boolean
local function available_on_path()
    return vim.fn.executable(HOST_BIN_NAME) == 1
end

--- Returns the name of the binary on the platform
--- @return string
local function bin_name()
    return HOST_BIN_NAME
end

--- @class InstallOpts
--- @field reinstall? boolean #If true, will force prompts and remove any previously-installed instance of the binary
--- @field bin? string #If provided, will overwrite the name of the binary used
--- @field prompt? string #If provided, used as prompt

--- Installs the binary asynchronously if unavailable, providing several options to perform
--- the installation
---
--- @overload fun(cb:fun(success:boolean, result:string)):number
--- @param opts InstallOpts
--- @param cb fun(success:boolean, result:string)
--- @return number #job-id on success, 0 on invalid arguments, -1 if unable to execute cmd
local function install(opts, cb)
    if not cb then
        cb = opts
        opts = {}
    end
    if not opts then
        opts = {}
    end

    vim.validate({
        opts = { opts, 'table' },
        cb = { cb, 'function' },
    })
    opts.reinstall = not (not opts.reinstall)

    local prompt = opts.prompt or (opts.reinstall and
        'Reinstalling local binary! What would you like to do?' or
        'Local binary not found! What would you like to do?')

    local choice = prompt_choices({
        prompt = prompt,
        choices = {
            'Download a prebuilt binary',
            'Build from source',
            'Copy local binary',
        },
    })

    if not choice then
        return cb(false, 'Aborted choice prompt')
    end

    if choice == 1 then
        return download_binary(cb)
    elseif choice == 2 then
        return build_binary(cb)
    elseif choice == 3 then
        return copy_binary(cb)
    end
end

--- @class ClientInstall
--- @field available_on_path fun():boolean
--- @field bin_name fun():string
--- @field exists fun():boolean
--- @field install fun(opts?: InstallOpts, cb:fun(success:boolean, err:string|nil)):number
--- @field path fun():string

--- @type ClientInstall
return {
    available_on_path = available_on_path,
    bin_name = bin_name,
    exists = exists,
    install = install,
    path = bin_path,
}
