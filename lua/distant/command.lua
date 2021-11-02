local editor = require('distant.editor')
local fn = require('distant.fn')

local command = {}

command.parse_input = function(input)
    local args = {}
    local opts = {}

    local TYPES = {
        EQUALS = 'equals',
        QUOTE = 'quote',
        WHITESPACE = 'whitespace',
        WORD = 'word',
    }

    local function to_char_type(char)
        if char == ' ' then
            return TYPES.WHITESPACE
        elseif char == '"' then
            return TYPES.QUOTE
        elseif char == '=' then
            return TYPES.EQUALS
        else
            return TYPES.WORD
        end
    end

    -- Parse our raw string into segments that are words, =, or quoted text
    local segments = {}
    local in_quote = false
    local in_pair = false
    local s = ''
    local function save_segment(ty)
        if not ty or (s == '' and not in_pair) then
            return
        end

        -- If in a key=value pair, we update the last item which is the key
        -- to be {key, value}
        if in_pair and (s ~= '' or ty ~= TYPES.QUOTE) then
            segments[#segments] = {segments[#segments], s}
            in_pair = false

        -- Otherwise, this is a new segment and we add it to the list
        elseif s ~= '' then
            table.insert(segments, s)
        end

        s = ''
    end
    local ty
    for i = 1, #input do
        local char = string.sub(input, i, i)
        ty = to_char_type(char)

        -- 1. If not in a quote and see a word, continue
        -- 2. If not in a quote and see a whitespace, save current text as segment
        -- 3. If not in a quote and see equals, save current text as segment
        -- 4. If not in a quote and see a quote, flag as in quote
        -- 4. If in quote, consume until see another quote
        -- 5. When saving a segment, check if this is the end of a key=value pair,
        --    if so then we want to take the last segment and convert it into a
        --    tuple of {key, value}
        if ty == TYPES.QUOTE then
            save_segment(ty)
            in_quote = not in_quote
        elseif in_quote then
            s = s .. char
        elseif ty == TYPES.WHITESPACE then
            save_segment(ty)
        elseif ty == TYPES.EQUALS then
            save_segment(ty)
            in_pair = not in_pair
        else
            s = s .. char
        end
    end

    -- Save the last segment if it exists
    save_segment(ty)
    assert(not in_quote, 'Unclosed quote pair encountered!')

    -- Split out args and opts
    for _, item in ipairs(segments) do
        if type(item) == 'string' and #item > 0 then
            table.insert(args, item)
        elseif type(item) == 'table' and #item == 2 then
            opts[item[1]] = item[2]
        end
    end

    -- For options, we transform keys that are comprised of dots into
    -- a nested table structure
    local new_opts = {}
    for key, value in pairs(opts) do
        -- Support key in form of path.to.key = value
        -- to produce { path = { to = { key = value } } }
        local path = vim.split(key, '.', true)

        if #path > 1 then
            local tbl = {}
            local keypair
            for i, component in ipairs(path) do
                keypair = keypair or tbl

                if i < #path then
                    keypair[component] = {}
                    keypair = keypair[component]
                else
                    keypair[component] = value
                end
            end

            new_opts = vim.tbl_deep_extend('keep', tbl, new_opts)
        else
            new_opts[key] = value
        end
    end

    return {
        args = args,
        opts = new_opts,
    }
end

--- Converts each path within table into a number using `tonumber()`
---
--- Paths are split by period, meaning `path.to.field` becomes
--- `tbl.path.to.field = tonumber(tbl.path.to.field)`
local function paths_to_number(tbl, paths)
    tbl = tbl or {}

    local parts, inner
    for _, path in ipairs(paths) do
        parts = vim.split(path, '.', true)
        inner = tbl
        for i, part in ipairs(parts) do
            if inner == nil then
                break
            end

            if i < #parts then
                inner = inner[part]
            end
        end
        if inner ~= nil and inner[parts[#parts]] ~= nil then
            inner[parts[#parts]] = tonumber(inner[parts[#parts]])
        end
    end
end

--- DistantOpen path [opt1=... opt2=...]
command.open = function(input)
    input = command.parse_input(input)
    paths_to_number(input.opts, {'buf', 'win'})

    local path = input.args[1]
    input.opts.path = path

    editor.open(input.opts)
end

--- DistantLaunch host [opt1=..., opt2=...]
command.launch = function(input)
    input = command.parse_input(input)
    paths_to_number(input.opts, {'ssh.port', 'timeout', 'interval'})

    local host = input.args[1]
    input.opts.host = host

    if type(host) ~= 'string' then
        vim.api.nvim_err_writeln('Missing host')
        return
    end

    editor.launch(input.opts, function(success, msg)
        if success then
            print('Connected to ' .. host)
        else
            vim.api.nvim_err_writeln(tostring(msg) or 'Launch failed without cause')
        end
    end)
end

--- DistantConnect host port [opt1=..., opt2=...]
command.connect = function(input)
    input = command.parse_input(input)
    paths_to_number(input.opts, {'timeout', 'interval'})

    if #input.args == 0 then
        vim.api.nvim_err_writeln('Missing host and port')
        return
    elseif #input.args == 1 then
        vim.api.nvim_err_writeln('Missing port')
        return
    end

    local host = input.args[1]
    input.opts.host = host

    local port = tonumber(input.args[2])
    input.opts.port = port

    editor.connect(input.opts, function(success, msg)
        if success then
            print('Connected to ' .. host .. ':' .. tostring(port))
        else
            vim.api.nvim_err_writeln(tostring(msg) or 'Connect failed without cause')
        end
    end)
end

--- DistantInstall [reload]
command.install = function(input)
    input = command.parse_input(input)
    local reload = input.args[1] == 'reload'
    require('distant.lib').load({reload = reload}, function(success, msg)
        if success then
            print('Successfully installed Rust library')
        else
            vim.api.nvim_err_writeln(tostring(msg) or 'Install failed without cause')
        end
    end)
end

--- DistantMetadata path [opt1=... opt2=...]
command.metadata = function(input)
    input = command.parse_input(input)
    paths_to_number(input.opts, {'timeout', 'interval'})

    local path = input.args[1]
    input.opts.path = path

    editor.show_metadata(input.opts)
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
command.copy = function(input)
    input = command.parse_input(input)
    paths_to_number(input.opts, {'timeout', 'interval'})

    local src = input.args[1]
    local dst = input.args[2]
    input.opts.src = src
    input.opts.dst = dst

    fn.copy(input.opts)
end

--- DistantMkdir path [opt1=... opt2=...]
command.mkdir = function(input)
    input = command.parse_input(input)
    paths_to_number(input.opts, {'timeout', 'interval'})

    local path = input.args[1]
    input.opts.path = path

    fn.create_dir(input.opts)
end

--- DistantRemove path [opt1=... opt2=...]
command.remove = function(input)
    input = command.parse_input(input)
    paths_to_number(input.opts, {'timeout', 'interval'})

    local path = input.args[1]
    input.opts.path = path

    fn.remove(input.opts)
end

--- DistantRename src dst [opt1=... opt2=...]
command.rename = function(input)
    input = command.parse_input(input)
    paths_to_number(input.opts, {'timeout', 'interval'})

    local src = input.args[1]
    local dst = input.args[2]
    input.opts.src = src
    input.opts.dst = dst

    fn.rename(input.opts)
end

--- DistantRun cmd [arg1 arg2 ...]
command.run = function(input)
    input = command.parse_input(input)
    paths_to_number(input.opts, {'timeout', 'interval'})

    local cmd = input.args[1]
    local cmd_args = vim.list_slice(input.args, 2, #input.args)
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
