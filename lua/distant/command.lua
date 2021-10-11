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

--- DistantOpen path [opt1=... opt2=...]
command.open = function(input)
    input = command.parse_input(input)
    local path = input.args[1]
    input.opts.path = path

    editor.open(input.opts)
end

--- DistantLaunch host [opt1=..., opt2=...]
command.launch = function(input)
    input = command.parse_input(input)
    local host = input.args[1]
    input.opts.host = host

    editor.launch(input.opts)
end

--- DistantMetadata path [opt1=... opt2=...]
command.metadata = function(input)
    input = command.parse_input(input)
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
    local src = input.args[1]
    local dst = input.args[2]
    input.opts.src = src
    input.opts.dst = dst

    fn.copy(input.opts)
end

--- DistantMkdir path [opt1=... opt2=...]
command.mkdir = function(input)
    input = command.parse_input(input)
    local path = input.args[1]
    input.opts.path = path

    fn.mkdir(input.opts)
end

--- DistantRemove path [opt1=... opt2=...]
command.remove = function(input)
    input = command.parse_input(input)
    local path = input.args[1]
    input.opts.path = path

    fn.remove(input.opts)
end

--- DistantRename src dst [opt1=... opt2=...]
command.rename = function(input)
    input = command.parse_input(input)
    local src = input.args[1]
    local dst = input.args[2]
    input.opts.src = src
    input.opts.dst = dst

    fn.rename(input.opts)
end

--- DistantRun cmd [arg1 arg2 ...]
command.run = function(input)
    input = command.parse_input(input)
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
