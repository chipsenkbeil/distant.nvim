local editor = require('distant.editor')
local fn = require('distant.fn')

local command = {}

local function parse_opts(...)
    local opts = {}

    for _, opt in pairs({...}) do
        local tokens = vim.split(opt, '=', true)

        -- Only accept in form of KEY=VALUE
        if #tokens == 2 then
            local key = vim.trim(tokens[1])
            local value = vim.trim(tokens[2])

            -- Support key in form of path.to.key = value
            -- to produce { path = { to = { key = value } } }
            local path = vim.split(key, '.', true)
            local tbl = opts
            for i, component in ipairs(path) do
                if i < #path then
                    tbl[component] = {}
                    tbl = tbl[component]
                else
                    tbl[component] = value
                end
            end
        end
    end

    return opts
end

--- DistantOpen path [opt1=... opt2=...]
command.open = function(...)
    local args = {...}
    local path = args[1]
    local opts = parse_opts(unpack(vim.list_slice(args, 2, #args)))
    opts.path = path

    editor.open(opts)
end

--- DistantLaunch host [opt1=..., opt2=...]
command.launch = function(...)
    local args = {...}
    local host = args[1]
    local opts = parse_opts(unpack(vim.list_slice(args, 2, #args)))
    opts.host = host

    editor.launch(opts)
end

--- DistantMetadata path [opt1=... opt2=...]
command.metadata = function(...)
    local args = {...}
    local path = args[1]
    local opts = parse_opts(unpack(vim.list_slice(args, 2, #args)))
    opts.path = path

    editor.show_metadata(opts)
end

--- DistantSessionInfo
command.session_info = function()
    editor.show_session_info()
end

--- DistantSystemInfo
command.system_info = function()
    editor.show_system_info()
end

--- DistantCopy src dst [opt1=... opt2=...]
command.copy = function(...)
    local args = {...}
    local src = args[1]
    local dst = args[2]
    local opts = parse_opts(unpack(vim.list_slice(args, 3, #args)))
    opts.src = src
    opts.dst = dst

    fn.copy(opts)
end

--- DistantMkdir path [opt1=... opt2=...]
command.mkdir = function(...)
    local args = {...}
    local path = args[1]
    local opts = parse_opts(unpack(vim.list_slice(args, 2, #args)))
    opts.path = path

    fn.mkdir(opts)
end

--- DistantRemove path [opt1=... opt2=...]
command.remove = function(...)
    local args = {...}
    local path = args[1]
    local opts = parse_opts(unpack(vim.list_slice(args, 2, #args)))
    opts.path = path

    fn.remove(opts)
end

--- DistantRename src dst [opt1=... opt2=...]
command.rename = function(...)
    local args = {...}
    local src = args[1]
    local dst = args[2]
    local opts = parse_opts(unpack(vim.list_slice(args, 3, #args)))
    opts.src = src
    opts.dst = dst

    fn.rename(opts)
end

--- DistantRun cmd [arg1 arg2]
command.run = function(...)
    local args = {...}
    local cmd = args[1]
    local cmd_args = vim.list_slice(args, 2, #args)
    local opts = {
        cmd = cmd,
        args = cmd_args,
    }

    local err, res = fn.spawn_wait(opts)
    assert(not err, err)

    if #res.stdout > 0 then
        print(res.stdout)
    end

    if #res.stderr > 0 then
        vim.api.nvim_err_writeln(res.stderr)
    end
end

return command
