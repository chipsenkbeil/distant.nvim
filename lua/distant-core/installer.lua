local utils                = require('distant-core.utils')

-------------------------------------------------------------------------------
-- CONFIGURATION DEFAULTS
-------------------------------------------------------------------------------

local REPO_URL             = 'https://github.com/chipsenkbeil/distant'
local RELEASE_API_ENDPOINT = 'https://api.github.com/repos/chipsenkbeil/distant/releases'
local MAX_DOWNLOAD_CHOICES = 10

-------------------------------------------------------------------------------
-- MAPPINGS
-------------------------------------------------------------------------------

--- Mapping of {os}:{arch} to artifact under releases
local PLATFORM_BIN         = {
    ['windows:x86_64']    = 'distant-win64.exe',
    ['macos:x86_64']      = 'distant-macos',
    ['macos:arm']         = 'distant-macos',
    ['linux:x86_64:gnu']  = 'distant-linux64-gnu-x86',
    ['linux:x86_64:musl'] = 'distant-linux64-musl-x86',
    ['linux:arm:gnu']     = 'distant-linux64-gnu-aarch64',
    ['linux:arm:musl']    = 'distant-linux64-musl-aarch64',
    ['linux:arm-v7:gnu']  = 'distant-linux64-gnu-arm-v7',
}

--- Mapping of type to local binary name we expect
local BIN_NAME             = {
    WINDOWS = 'distant.exe',
    UNIX    = 'distant',
}

-------------------------------------------------------------------------------
-- INTERNAL GITHUB API
-------------------------------------------------------------------------------

--- @param tag string
--- @return Version|nil
local function parse_tag_into_version(tag)
    return utils.parse_version(utils.strip_prefix(vim.trim(tag), 'v'))
end

--- @class QueryReleaseApiOpts
--- @field page? number #Page in release list to query, defaulting to first page
--- @field per_page? number #Number of entries to query for a page

--- @param opts QueryReleaseApiOpts
--- @param cb fun(err?:string, result?:table)
local function query_release_api(opts, cb)
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
        cb('No external command is available. Please install curl, wget, or fetch!', nil)
    end

    local json_str, err
    vim.fn.jobstart(cmd, {
        on_exit = function(_, exit_code)
            if exit_code ~= 0 then
                cb('Exit ' .. tostring(exit_code) .. ': ' .. tostring(err), nil)
            else
                local success, value = pcall(vim.fn.json_decode, json_str or '')
                if success then
                    cb(nil, value)
                else
                    cb(tostring(value), nil)
                end
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
--- @param cb fun(err?:string, entries?:ReleaseEntry[])
local function query_release_list(opts, cb)
    vim.validate({ opts = { opts, 'table' }, cb = { cb, 'function' } })
    if type(opts.asset_name) ~= 'string' then
        error('opts.asset_name is required and must be a string')
    end

    query_release_api({ page = opts.page, per_page = opts.per_page }, function(err, res)
        if err then
            cb(err, nil)
            return
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

        cb(nil, entries)
    end)
end

--- Downloads src using curl, wget, or fetch and stores it at dst
--- @param src string #url to download from
--- @param dst string #destination to store artifact
--- @param cb fun(err?:string, path?:string) #where result is an error message or the binary path
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
        cb('No external command is available. Please install curl, wget, or fetch!', nil)
        return
    end

    -- Create a new buffer to house our terminal window
    local bufnr = vim.api.nvim_create_buf(false, true)
    assert(bufnr ~= 0, 'Failed to create buffer')
    vim.api.nvim_win_set_buf(0, bufnr)

    vim.fn.termopen(cmd, {
        pty = true,
        on_exit = function(_, exit_code)
            if exit_code ~= 0 then
                vim.schedule(function()
                    cb(string.format('%s failed (%s)', cmd, exit_code), nil)
                end)
            else
                -- Close out the terminal window
                vim.api.nvim_buf_delete(bufnr, { force = true })

                vim.schedule(function()
                    cb(nil, dst)
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

--- @return string #Path to directory that would contain the binary
local function bin_dir()
    return utils.data_path() .. SEP .. 'bin'
end

--- @return string #Path to local binary
local function bin_path()
    return bin_dir() .. SEP .. HOST_BIN_NAME
end

-- From https://www.lua.org/pil/19.3.html
local function pair_by_keys(t, f)
    local a = {}
    for n in pairs(t) do table.insert(a, n) end
    table.sort(a, f)
    local i = 0
    local iter = function()
        i = i + 1
        if a[i] == nil then
            return nil
        else
            return a[i], t[a[i]]
        end
    end
    return iter
end

-------------------------------------------------------------------------------
-- INSTALL HELPERS
-------------------------------------------------------------------------------

--- @class DownloadBinaryOpts
--- @field bin_name? string #Name of binary artifact to download, defaulting to platform choice
--- @field min_version? Version #Minimum version to list as a download choice

--- @param opts DownloadBinaryOpts
--- @param cb fun(err?:string, path?:string) #where result is an error message or the binary path
local function download_binary(opts, cb)
    vim.validate({ opts = { opts, 'table' }, cb = { cb, 'function' } })

    --- @type string
    local host_platform = HOST_PLATFORM

    local bin_name = opts.bin_name
    local min_version = opts.min_version

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
        cb('No binary available for ' .. host_platform, nil)
        return
    end

    query_release_list({ asset_name = bin_name }, function(err, entries)
        if err then
            cb(err, nil)
            return
        end

        local choices = vim.tbl_map(
            function(entry) return entry.description end,
            vim.tbl_filter(function(entry)
                local version = parse_tag_into_version(entry.tag)
                return not min_version or ((not not version) and utils.can_upgrade_version(
                    min_version,
                    version,
                    { allow_unstable_upgrade = true }
                ))
            end, entries)
        )
        local choice = prompt_choices({
            prompt = 'Which version of the binary do you want?',
            choices = choices,
            max_choices = MAX_DOWNLOAD_CHOICES,
        })
        local entry = entries[choice]
        if not entry then
            cb('Cancelled selecting binary version', nil)
            return
        end

        download(entry.url, bin_path(), cb)
    end)
end

--- @param path? string
--- @param cb fun(err?:string, path?:string) #where result is an error message or the binary path
local function copy_binary(path, cb)
    vim.validate({ path = { path, 'string', true }, cb = { cb, 'function' } })

    if not path then
        path = vim.fn.input('Path to binary: ')
    end

    if path and #path > 0 then
        local dst = bin_path()
        vim.loop.fs_copyfile(path, dst, function(err, success)
            vim.schedule(function()
                if err then
                    cb(err, nil)
                elseif not success then
                    cb('Failed to copy ' .. path .. ' to ' .. dst, nil)
                else
                    cb(nil, dst)
                end
            end)
        end)
    else
        cb('Binary path missing', nil)
    end
end

--- @param cb fun(err?:string, path?:string) #where result is an error message or the repo path
local function clone_repository(cb)
    if tonumber(vim.fn.executable('git')) ~= 1 then
        cb('git not found in path', nil)
        return
    end

    local tmpdir = vim.fn.tempname()
    local cmd = string.format('git clone --depth 1 %s %s', REPO_URL, tmpdir)

    -- Create a new buffer to house our terminal window
    local bufnr = vim.api.nvim_create_buf(false, true)
    assert(bufnr ~= 0, 'Failed to create buffer')
    vim.api.nvim_win_set_buf(0, bufnr)

    vim.fn.termopen(cmd, {
        pty = true,
        on_exit = function(_, exit_code)
            if exit_code ~= 0 then
                vim.fn.delete(tmpdir, 'rf')
                vim.schedule(function()
                    cb(string.format('%s failed (%s)', cmd, exit_code), nil)
                end)
            else
                -- Close out the terminal window
                vim.api.nvim_buf_delete(bufnr, { force = true })

                vim.schedule(function()
                    cb(nil, tmpdir)
                end)
            end
        end
    })
end


--- @param cb fun(err?:string, path?:string) #where result is an error message or the binary path
local function build_binary(cb)
    clone_repository(function(err, path)
        if err then
            vim.schedule(function() cb(err, nil) end)
            return
        end

        if tonumber(vim.fn.executable('cargo')) ~= 1 then
            cb('cargo not found in path', nil)
            return
        end

        -- Create a new buffer to house our terminal window
        local bufnr = vim.api.nvim_create_buf(false, true)
        assert(bufnr ~= 0, 'Failed to create buffer')
        vim.api.nvim_win_set_buf(0, bufnr)

        -- $ROOT/distant/Cargo.toml
        local cargo_toml = path .. SEP .. 'Cargo.toml'

        -- $ROOT/distant/target/release/{bin}
        local release_bin = path .. SEP .. 'target' .. SEP .. 'release' .. SEP
        if HOST_OS == 'windows' then
            release_bin = release_bin .. 'distant.exe'
        else
            release_bin = release_bin .. 'distant'
        end

        -- Build release binary
        local cmd = string.format('cargo build --release', cargo_toml)
        vim.fn.termopen(cmd, {
            cwd = path,
            pty = true,
            on_exit = function(_, exit_code)
                if exit_code ~= 0 then
                    vim.fn.delete(path, 'rf')
                    vim.schedule(function()
                        cb(string.format('%s failed (%s)', cmd, exit_code), nil)
                    end)
                else
                    -- Close out the terminal window
                    vim.api.nvim_buf_delete(bufnr, { force = true })

                    vim.schedule(function()
                        copy_binary(release_bin, function(status, msg)
                            vim.fn.delete(path, 'rf')
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

local M = {
    path = bin_path,
    dir = bin_dir,
}

--- Returns true if the binary is loaded, otherwise return false
--- @return boolean
function M.exists()
    return vim.fn.executable(bin_path()) == 1
end

--- Returns true if the binary is available on our path, even if not locally
--- @return boolean
function M.available_on_path()
    return vim.fn.executable(HOST_BIN_NAME) == 1
end

--- Returns the name of the binary on the platform
--- @return 'distant'|'distant.exe'
function M.bin_name()
    return HOST_BIN_NAME
end

--- Installs the binary asynchronously if unavailable, providing several options to perform
--- the installation:
--
--- * `reinstall` If true, will force prompts and remove any previously-installed instance of the binary
--- * `bin` If provided, will overwrite the name of the binary used
--- * `prompt` If provided, used as prompt
--- * `min_version` If provided, filters download options to only those that meet specified version
---
--- Upon completion, the callback is triggered with either an error or the path to the binary.
---
--- @param opts {reinstall?:boolean, bin?:string, prompt?:string, min_version?:Version}
--- @param cb fun(err?:string, path?:string)
function M.install(opts, cb)
    vim.validate({
        opts = { opts, 'table' },
        cb = { cb, 'function' },
    })
    opts.reinstall = not (not opts.reinstall)

    local local_bin = bin_path()
    local has_bin = vim.fn.executable(local_bin) == 1
    local min_version = opts.min_version
    if has_bin then
        print('Local cli available at ' .. local_bin)
    end

    local prompt = opts.prompt
    if not prompt then
        if opts.reinstall then
            prompt = 'Reinstalling local binary! What would you like to do?'
        else
            prompt = 'Local binary not found! What would you like to do?'
        end
    end

    -- If we are given a minimum version and have a pre-existing binary,
    -- we want to check the version to see if we can return it
    if has_bin and min_version and not opts.reinstall then
        local version = has_bin and utils.exec_version(local_bin)
        local valid_version = version and utils.can_upgrade_version(
            min_version,
            version,
            { allow_unstable_upgrade = true }
        )

        if valid_version then
            cb(nil, local_bin)
            return
        elseif version then
            prompt = string.format(
                'Installed cli version is %s, which is not backwards-compatible with %s! '
                .. 'What would you like to do?',
                utils.version_to_string(version),
                utils.version_to_string(min_version)
            )
        end

        -- Otherwise, if we have a binary and no minimum required version,
        -- then we're good to go and can exit immediately
    elseif has_bin and not opts.reinstall then
        cb(nil, local_bin)
        return
    end

    local choice = prompt_choices({
        prompt = prompt,
        choices = {
            'Download a prebuilt binary',
            'Build from source',
            'Copy local binary',
        },
    })

    if not choice then
        cb('Aborted choice prompt', nil)
        return
    end

    local do_action = function()
        local cb_wrapper = vim.schedule_wrap(function(err, path)
            if err then
                cb(err, nil)
                return
            end

            assert(path, 'Path nil without error!')

            -- If we succeeded, we need to make sure the binary is executable on Unix systems
            -- and we do this by getting the pre-existing mode and ensuring that it is
            -- executable
            vim.loop.fs_stat(path, vim.schedule_wrap(function(err, stat)
                if err then
                    cb(err, nil)
                    return
                end

                -- Mode comes in as a decimal representing octal value
                -- and we want to ensure that it has executable permissions
                local mode = utils.bitmask(
                    stat.mode or 493, -- 0o755 -> 493
                    73,               -- 0o111 -> 73
                    'or'
                )

                vim.loop.fs_chmod(path, mode, vim.schedule_wrap(function(err, success)
                    if err then
                        cb(err, nil)
                    elseif not success then
                        cb('Failed to change binary permissions', nil)
                    else
                        cb(nil, path)
                    end
                end))
            end))
        end)

        -- Perform action to get binary
        if choice == 1 then
            download_binary({ min_version = opts.min_version }, cb_wrapper)
        elseif choice == 2 then
            build_binary(cb_wrapper)
        elseif choice == 3 then
            copy_binary(nil, cb_wrapper)
        end
    end

    -- If we have a bin and were given a choice, we want to delete the old binary
    -- before installing the new one to avoid weird corruption
    if has_bin then
        vim.loop.fs_unlink(local_bin, vim.schedule_wrap(function(err, success)
            if err then
                cb('Failed to remove old binary: ' .. err, nil)
            elseif not success then
                cb('Failed to remove old binary: ???', nil)
            end

            do_action()
        end))
    else
        -- Ensure that the directory to house the binary exists
        utils.mkdir({ path = bin_dir(), parents = true }, function(err)
            if err then
                cb('Unable to create directory for binary: ' .. err, nil)
            end

            do_action()
        end)
    end
end

return M
