local utils = {}

--- Builds an argument string by taking a table's keys and converting them
--- into arguments:
---
--- 1. If the key's value is not a number, string, or boolean, it is ignored
--- 2. If the key's value is nil or false, it is ignored
--- 3. If the key's value is true, it is converted into "--key"
--- 4. Otherwise, it is converted into "--key value"
---
--- Keys with underscores have them replaced with hyphens such that
--- "my_long_key" becomes "--my-long-key"
---
--- An optional table `ignore` can be provided that contains keys that should be
--- skipped from args when building the argument string
---
--- Returns the string representing the arguments
utils.build_arg_str = function(args, ignore)
    local s = ''
    ignore = ignore or {}

    for k, v in pairs(args) do
        -- Skip positional arguments and nil/false values
        if not utils.contains(ignore, k) and v then
            local name = k:gsub('_', '-')
            if type(v) == 'boolean' then
                s = s .. ' --' .. name
            elseif type(v) == 'number' or type(v) == 'string' then
                s = s .. ' --' .. name .. ' ' .. v
            end
        end
    end

    return vim.trim(s)
end

--- Start an async job using the given cmd and options
---
--- Options supports the following:
---
--- * on_success: a function that is triggered with no arguments once the
---               job finishes successfully
--- * on_failure: a function that is triggered with an exit code as the single
---               argument once the job finishes unsuccessfully
--- * on_stdout_line: a function that is triggered once per line of stdout
--- * on_stderr_line: a function that is triggered once per line of stderr
---
--- Returned is a new table that contains two functions:
---
--- * id: a function that returns the id of the job
--- * write: a function that takes a string as the single argument to send to
---          the stdin of the running job
--- * stop: a function that takes no arguments and stops the running job
utils.job_start = function(cmd, opts)
    local function make_on_data(cb)
        local lines = {''}
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
                for i, v in ipairs(data) do
                    if i < #data then
                        send_back(v)
                    end
                end

                -- Remove all lines but the last one
                lines = {lines[#lines]}
            end
        end
    end

    local job_id =  vim.fn.jobstart(cmd, {
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
        utils.log_err('Invalid arguments: ' .. cmd)
    elseif job_id == -1 then
        utils.log_err('Cmd is not executable: ' .. cmd)
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

--- Logs an error
utils.log_err = function(err)
    assert(type(err) == 'string', 'Error must be a string')
    vim.api.nvim_err_writeln(err)
end

--- Returns a new id for use in sending messages
utils.next_id = function()
    return math.floor(math.random() * 10000)
end

--- Defines an augroup
utils.augroup = function(name, cb)
    vim.cmd('augroup ' .. name)
    vim.cmd('autocmd!')
    cb()
    vim.cmd('augroup END')
end

--- Defines an autocmd (use within augroup)
utils.autocmd = function(name, pattern, cmd)
    local cmd_type = type(cmd)
    if cmd_type == 'function' then
        local key = '__distant_autocmd_callback_' .. utils.next_id() .. '__'
        senkwich.g[key] = cmd
        cmd = 'lua distant.g["' .. key .. '"]()'
    elseif cmd_type ~= 'string' then
        error('autocmd(): unsupported cmd type: ' .. cmd_type)
    end
    vim.cmd('autocmd ' .. name .. ' ' .. pattern .. ' ' .. cmd)
end

--- Merges N tables together into a new table
utils.merge = function(...)
    local dst = {}

    -- For each vararg, process it and merge items if it is a table;
    -- otherwise, skip it
    for _, tbl in ipairs({...}) do
        if type(tbl) == 'table' then
            -- For each item in the table, we merge in one of three ways:
            -- 1. If the dst does not have a matching key, we assign the current
            --    table's value to it
            -- 2. If the types of dst and current table are both table, we
            --    recursively apply a merge
            -- 3. Otherwise, we assign the current table's value to dst's key
            for k, v in pairs(tbl) do
                if dst[k] == nil or type(dst[k]) ~= 'table' or type(v) ~= 'table' then
                    dst[k] = utils.deepcopy(v)
                else 
                    dst[k] = utils.merge(dst[k], v)
                end
            end
        end
    end

    return dst
end

--- Performs a deep copy of some data
--- From http://lua-users.org/wiki/CopyTable
---
--- @param orig any The data to deeply copy
--- @param copies table Internal parameter used for recursion (do not use externally)
--- @return any data The newly-copied instance
utils.deepcopy = function(orig, copies)
    copies = copies or {}
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        if copies[orig] then
            copy = copies[orig]
        else
            copy = {}
            copies[orig] = copy
            for orig_key, orig_value in next, orig, nil do
                copy[utils.deepcopy(orig_key, copies)] = utils.deepcopy(orig_value, copies)
            end
            setmetatable(copy, utils.deepcopy(getmetatable(orig), copies))
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

--- Checks if string begins with start string
--- From http://lua-users.org/wiki/StringRecipes
---
--- @param str string The string whose content to check
--- @param start string The expected beginning
--- @return boolean result True if a match, otherwise false
utils.starts_with = function(str, start)
   return str:sub(1, #start) == start
end

--- Produces a table of N lines all with the same text
---
--- @param n number The total number of lines to produce
--- @param line string The line to replicate
--- @return table lines The table of lines {'line', 'line', ...}
utils.make_n_lines = function(n, line)
    local lines = {}

    for i = 1, n do
        table.insert(lines, line)
    end

    return lines
end

--- Produces a send/receive pair in the form of {tx, rx} where
--- tx is a function that sends a message and rx is a function that
--- waits for the message
---
--- @param timeout is the milliseconds that rx will wait
--- @param interval is the milliseconds to wait inbetween checking for a message
utils.oneshot_channel = function(timeout, interval)
    assert(type(timeout) == 'number', 'timeout must be a number')
    assert(type(interval) == 'number', 'interval must be a number')

    local tmp_name = '__oneshot_' .. utils.next_id() .. '__'
    assert(not utils.nvim_has_var(tmp_name), tmp_name .. ' already exists')

    local tx = function(msg)
        local data_str = vim.fn.json_encode(msg)
        vim.api.nvim_set_var(tmp_name, data_str)
    end

    local rx = function()
        -- Wait for the result to be set, or time out
        vim.fn.wait(
            timeout,
            function() return utils.nvim_has_var(tmp_name) end,
            interval
        )

        -- Grab and clear our temporary variable if it is set and return it's value
        local result = utils.nvim_remove_var(tmp_name)
        if result ~= nil and type(result) == 'string' then
            result = vim.fn.json_decode(result)
        end

        return result
    end

    return {
        tx = tx; 
        rx = rx;
    }
end

return utils
