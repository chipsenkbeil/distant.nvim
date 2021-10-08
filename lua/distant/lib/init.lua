local BASE_URL = 'https://github.com/chipsenkbeil/distant/releases/latest/download'

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
local function download(src, dst)
    local cmd
    if tonumber(vim.fn.executable('curl')) == 1 then
        cmd = string.format('curl -fLo %s --create-dirs %s', dst, src)
    elseif tonumber(vim.fn.executable('wget')) == 1 then
        cmd = string.format('wget -O %s %s', dst, src)
    elseif tonumber(vim.fn.executable('fetch')) == 1 then
        cmd = string.format('fetch -o %s %s', dst, src)
    end

    if not cmd then
        error('No external command is available. Please install curl, wget, or fetch!')
    end

    local out = vim.fn.system(cmd)
    local errno = tonumber(vim.v.shell_error)
    if errno ~= 0 then
        error(string.format('%s failed (%s): %s', cmd, errno, out))
    end
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

-- TODO: Properly detect if this library is accessible. If not, we need to provide
--       two options:
--
--       1. Download a pre-built library using curl for the detected OS
--       2. Build from source by cloning the repository, running cargo build --release,
--          and copying the release artifact to the appropriate location
return (function()
    local success, lib = pcall(require, 'distant_lua')
    if success then
        return lib
    end

    local choice = vim.fn.inputlist({
        'distant_lua not found! What would you like to do?',
        '1. Download a prebuilt lib',
        '2. Build from source',
    })
    if choice == 1 then
        local os, arch = detect_os_arch()
        local lib_name = PLATFORM_LIB[os .. ':' .. arch]

        if not lib_name then
            local args = {string.format(
                'Unknown platform %s:%s! Please select from the following:', os, arch
            )}
            local libs = {}
            for platform, platform_lib in pairs(PLATFORM_LIB) do
                table.insert(args, string.format('%s. %s', #args, platform))
                table.insert(libs, platform_lib)
            end
            local idx = vim.fn.inputlist(args)
            lib_name = libs[idx]
        end

        if not lib_name then
            error('No lib available for ' .. os .. ':' .. arch)
        end

        local sep
        if os == 'windows' then
            sep = '\\'
        else
            sep = '/'
        end

        local url = string.format('%s/%s', BASE_URL, lib_name)

        -- script_path -> /path/to/lua/distant/lib/{distant_lua.so}
        -- up -> /path/to/lua/distant/{distant_lua.so}
        -- up -> /path/to/lua/{distant_lua.so}
        local get_parent_path = make_path_parent_fn(sep)
        local dst = get_parent_path(get_parent_path(script_path()))
        if vim.endswith(lib_name, 'dll') then
            dst = dst .. sep .. 'distant_lua.dll'
        else
            dst = dst .. sep .. 'distant_lua.so'
        end

        -- TODO: Display progress
        print(string.format('Downloading %s', url))
        download(url, dst)
    elseif choice == 2 then
        assert(false, 'TODO: git clone repo, cargo build release, and copy artifact')
    else
        error('distant_lua is not available!')
    end

    return require('distant_lua')
end)()
