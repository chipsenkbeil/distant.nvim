local REPO_URL = 'https://github.com/chipsenkbeil/distant'
local REPO_RELEASE_URL = REPO_URL .. '/releases/latest/download'

local PLATFORM_BIN = {
    ['windows:x86_64'] = 'distant-win64.exe',
    ['linux:x86_64'] = 'distant-linux64-gnu',
    ['macos:x86_64'] = 'distant-macos',
    ['macos:arm'] = 'distant-macos',
}

local PLATFORM_LIB = {
    ['windows:x86_64'] = 'distant_lua-win64.dll',
    ['linux:x86_64'] = 'distant_lua-linux64.so',
    ['macos:x86_64'] = 'distant_lua-macos.dylib',
    ['macos:arm'] = 'distant_lua-macos.dylib',
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

-- Downloads src using curl, wget, or fetch and stores it at dst
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

-- Original from https://gist.github.com/soulik/82e9d02a818ce12498d1
--
-- Returns OS, arch
--
-- ### Operating Systems
--
-- * windows
-- * linux
-- * macos
-- * bsd
-- * solaris
-- * unknown
--
-- ### Architectures
--
-- * x86
-- * x86_64
-- * powerpc
-- * arm
-- * mips
-- * unknown
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

local function prompt_choices(prompt, choices)
    local args = {prompt}
    for i, choice in ipairs(choices) do
        table.insert(args, string.format('%s. %s', i, choice))
    end

    local choice = vim.fn.inputlist(args)
    if choice > 0 and choice <= #choices then
        return choice
    end
end

-- Constants
local HOST_OS, HOST_ARCH = detect_os_arch()
local HOST_PLATFORM = HOST_OS .. ':' .. HOST_ARCH
local SEP = HOST_OS == 'windows' and '\\' or '/'
local ROOT_DIR = (function()
    -- script_path -> /path/to/lua/distant/lib/{distant_lua.so}
    -- up -> /path/to/lua/distant/{distant_lua.so}
    -- up -> /path/to/lua/{distant_lua.so}
    local get_parent_path = make_path_parent_fn(SEP)
    return get_parent_path(get_parent_path(script_path()))
end)()

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

local function download_library(cb)
    local lib_name = PLATFORM_LIB[HOST_PLATFORM]

    if not lib_name then
        local choices = {}
        local libs = {}
        for platform, platform_lib in pair_by_keys(PLATFORM_LIB) do
            table.insert(choices, platform)
            table.insert(libs, platform_lib)
        end
        local idx = prompt_choices(
            string.format('\nUnknown platform %s! Please select from the following:', HOST_PLATFORM),
            choices
        )
        if idx then
            lib_name = libs[idx]
        end
    end

    if not lib_name then
        return cb(false, 'No library available for ' .. HOST_PLATFORM)
    end

    local url = string.format('%s/%s', REPO_RELEASE_URL, lib_name)

    local dst = ROOT_DIR
    if vim.endswith(lib_name, 'dll') then
        dst = dst .. SEP .. 'distant_lua.dll'
    else
        dst = dst .. SEP .. 'distant_lua.so'
    end

    -- TODO: Display progress
    return download(url, dst, cb)
end

local function copy_library(path, cb)
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
        local lib_file = io.open(path, 'r')
        if not lib_file then
            return cb(false, path .. ' does not exist')
        end
        local contents = lib_file:read('*a')
        lib_file:close()

        local dst = ROOT_DIR
        if vim.endswith(path, 'dll') then
            dst = dst .. SEP .. 'distant_lua.dll'
        else
            dst = dst .. SEP .. 'distant_lua.so'
        end

        local dst_file = io.open(dst, 'w')
        dst_file:write(contents)
        dst_file:close()

        cb(true)
    else
        cb(false, 'Library path missing')
    end
end

local function clone_library(cb)
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

local function build_library(cb)
    return clone_library(function(success, tmpdir)
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
            release_lib = release_lib .. 'distant_lua.dll'
        elseif HOST_OS == 'macos' then
            release_lib = release_lib .. 'libdistant_lua.dylib'
        else
            release_lib = release_lib .. 'libdistant_lua.so'
        end

        -- Build release library
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
                        copy_library(release_lib, function(status, msg)
                            vim.fn.delete(tmpdir, 'rf')
                            cb(status, msg)
                        end)
                    end)
                end
            end
        })
    end)
end

local function load(cb)
    local success, lib = pcall(require, 'distant_lua')
    if success then
        return cb(success, lib)
    end

    local choice
    choice = prompt_choices('C library not found! What would you like to do?', {
        'Download a prebuilt lib',
        'Build from source',
        'Use local copy',
    })

    if not choice then
        error('distant_lua is not available!')
    end

    if choice == 1 then
        return download_library(function(status, msg)
            if not status then
                return cb(status, msg)
            end
            cb(pcall(require, 'distant_lua'))
        end)
    elseif choice == 2 then
        return build_library(function(status, msg)
            if not status then
                return cb(status, msg)
            end
            cb(pcall(require, 'distant_lua'))
        end)
    elseif choice == 3 then
        return copy_library(function(status, msg)
            if not status then
                return cb(status, msg)
            end
            cb(pcall(require, 'distant_lua'))
        end)
    end
end

return { load = load }
