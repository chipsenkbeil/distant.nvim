local M = {}

--- Parse <args> from a neovim command.
--- @param input string
--- @return {args:string[], opts:table<string, string|table>}
function M.parse_args(input)
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
            segments[#segments] = { segments[#segments], s }
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
        local path = vim.split(key, '.', { plain = true })

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

--- Converts each path within table into a value using `f()`
---
--- Paths are split by period, meaning `path.to.field` becomes
--- `tbl.path.to.field = f(tbl.path.to.field)`
--- @generic T
--- @param tbl table
--- @param paths string[]
--- @param f fun(value:string):T
function M.paths_to_f(tbl, paths, f)
    tbl = tbl or {}

    local parts, inner
    for _, path in ipairs(paths) do
        --- @type string[]
        parts = vim.split(path, '.', { plain = true })

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
            inner[parts[#parts]] = f(inner[parts[#parts]])
        end
    end
end

--- Converts each path within table into a number using `tonumber()`
---
--- Paths are split by period, meaning `path.to.field` becomes
--- `tbl.path.to.field = tonumber(tbl.path.to.field)`
--- @param tbl table
--- @param paths string[]
function M.paths_to_number(tbl, paths)
    return M.paths_to_f(tbl, paths, tonumber)
end

--- Converts each path within table into a bool using `value == 'true'`
---
--- Paths are split by period, meaning `path.to.field` becomes
--- `tbl.path.to.field = tbl.path.to.field == 'true'`
--- @param tbl table
--- @param paths string[]
function M.paths_to_bool(tbl, paths)
    return M.paths_to_f(tbl, paths, function(value) return value == 'true' end)
end

return M
