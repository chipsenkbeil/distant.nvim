local s = require('distant.internal.state')
local u = require('distant.internal.utils')

local fn = {}

-------------------------------------------------------------------------------
-- SYNC FUNCTIONS
-------------------------------------------------------------------------------

--- Copies a remote file or directory to a new location
---
--- @param src string Path to the input file/directory to copy
--- @param dst string Path to the output file/directory
--- @param opts.timeout number Maximum time to wait for a response
--- @param opts.interval number Time in milliseconds to wait between checks for a response
--- @return boolean result true if succeeded, otherwise false
fn.copy = function(src, dst, opts)
    opts = opts or {}
    local tx, rx = u.oneshot_channel(
        opts.timeout or s.settings.max_timeout,
        opts.interval or s.settings.timeout_interval
    )

    fn.async.copy(src, dst, tx)
    local err1, err2, result = rx()
    return err1 or err2, result
end

--- Retrieves a list of contents within a remote directory
---
--- @param path string Path to the directory whose contents to list
--- @param opts.depth number Will recursively retrieve all contents up to the specified depth
---        with 0 indicating that depth limit is unlimited
--- @param opts.absolute boolean If true, will return absolute paths instead of relative paths
--- @param opts.canonicalize boolean If true, will canonicalize paths, meaning following the
---        symlinks; note that to return absolute paths you must set the other option
--- @param opts.include_root boolean If true, will include the path provided as the root entry
---        in the response
--- @param opts.timeout number Maximum time to wait for a response
--- @param opts.interval number Time in milliseconds to wait between checks for a response
--- @return table entries A list of entries in the form of
---         {'path' = ..., 'file_type' = ..., 'depth' = ...}
---         or nil if unsuccessful
fn.dir_list = function(path, opts)
    opts = opts or {}
    local tx, rx = u.oneshot_channel(
        opts.timeout or s.settings.max_timeout,
        opts.interval or s.settings.timeout_interval
    )

    fn.async.dir_list(path, opts, tx)
    local err1, err2, result = rx()
    return err1 or err2, result
end

--- Checks whether or not the provided path exists on the remote machine
---
--- @param path string Path to the file, directory, or symlink
--- @param opts.timeout number Maximum time to wait for a response
--- @param opts.interval number Time in milliseconds to wait between checks for a response
--- @return string|nil error, boolean|nil exists
fn.exists = function(path, opts)
    opts = opts or {}
    local tx, rx = u.oneshot_channel(
        opts.timeout or s.settings.max_timeout,
        opts.interval or s.settings.timeout_interval
    )

    fn.async.exists(path, tx)
    local err1, err2, result = rx()
    return err1 or err2, result
end

--- Retrieves filesystem metadata about a remote file, directory, or symlink
---
--- @param path string Path to the file, directory, or symlink
--- @param opts.canonicalize boolean If true, includes a canonicalized version
---        of the path in the response
--- @param opts.timeout number Maximum time to wait for a response
--- @param opts.interval number Time in milliseconds to wait between checks for a response
--- @return table metadata Table in the following format where `accessed`, `created`,
---         and `modified` are optional and may be missing from the table
--
---         {
---             canonicalized_path = "...";
---             file_type = "dir|file|sym_link";
---             len = 1234;
---             readonly = true;
---             accessed = 1234;
---             created = 1234;
---             modified = 1234;
---         }
---
---         `len` is total bytes of file. `accessed`, `created`, and `modified` are
---         all in terms in milliseconds since UNIX epoch.
fn.metadata = function(path, opts)
    opts = opts or {}
    local tx, rx = u.oneshot_channel(
        opts.timeout or s.settings.max_timeout,
        opts.interval or s.settings.timeout_interval
    )

    fn.async.metadata(path, opts, tx)
    local err1, err2, result = rx()
    return err1 or err2, result
end

--- Creates a remote directory
---
--- @param path string Path to the directory to create
--- @param opts.all boolean If true, will recursively all components of path to directory
--- @param opts.timeout number Maximum time to wait for a response
--- @param opts.interval number Time in milliseconds to wait between checks for a response
--- @return boolean result true if succeeded, otherwise false
fn.mkdir = function(path, opts)
    opts = opts or {}
    local tx, rx = u.oneshot_channel(
        opts.timeout or s.settings.max_timeout,
        opts.interval or s.settings.timeout_interval
    )

    fn.async.mkdir(path, opts, tx)
    local err1, err2, result = rx()
    return err1 or err2, result
end

--- Reads a remote file as text
---
--- @param path string Path to the file to read
--- @param opts.timeout number Maximum time to wait for a response
--- @param opts.interval number Time in milliseconds to wait between checks for a response
--- @return string text file's text, or nil if fails
fn.read_file_text = function(path, opts)
    opts = opts or {}
    local tx, rx = u.oneshot_channel(
        opts.timeout or s.settings.max_timeout,
        opts.interval or s.settings.timeout_interval
    )

    fn.async.read_file_text(path, tx)
    local err1, err2, result = rx()
    return err1 or err2, result
end

--- Removes a remote file or directory
---
--- @param path string Path to the file or directory to create
--- @param opts.force boolean If true, will remove directories that are non-empty
--- @param opts.timeout number Maximum time to wait for a response
--- @param opts.interval number Time in milliseconds to wait between checks for a response
--- @return boolean result true if succeeded, otherwise false
fn.remove = function(path, opts)
    opts = opts or {}
    local tx, rx = u.oneshot_channel(
        opts.timeout or s.settings.max_timeout,
        opts.interval or s.settings.timeout_interval
    )

    fn.async.remove(path, opts, tx)
    local err1, err2, result = rx()
    return err1 or err2, result
end

--- Renames a remote file or directory
---
--- @param src string Path to the file or directory to rename
--- @param dst string Path to the new file or directory
--- @param opts.timeout number Maximum time to wait for a response
--- @param opts.interval number Time in milliseconds to wait between checks for a response
--- @return boolean result true if succeeded, otherwise false
fn.rename = function(src, dst, opts)
    opts = opts or {}
    local tx, rx = u.oneshot_channel(
        opts.timeout or s.settings.max_timeout,
        opts.interval or s.settings.timeout_interval
    )

    fn.async.rename(src, dst, tx)
    local err1, err2, result = rx()
    return err1 or err2, result
end

--- Executes a remote program
---
--- @param cmd string Name of the command to run
--- @param args list Array of arguments to append to the command
--- @param opts.timeout number Maximum time to wait for the program to finish
--- @param opts.interval number Time in milliseconds to wait between checks for program to finish
--- @return table output Table with code, stdout, and stderr fields where
---         stdout and stderr are lists of individual lines of output, or
---         returns nil if timeout
fn.run = function(cmd, args, opts)
    opts = opts or {}
    local tx, rx = u.oneshot_channel(
        opts.timeout or s.settings.max_timeout,
        opts.interval or s.settings.timeout_interval
    )

    fn.async.run(cmd, args, tx)
    local err1, err2, result = rx()
    return err1 or err2, result
end

--- Requests information about the remote system
---
--- @param opts.timeout number Maximum time to wait for the program to finish
--- @param opts.interval number Time in milliseconds to wait between checks for program to finish
--- @return table output Table with family, os, arch, current_dir, and main_separator;
---         or returns nil if timeout
fn.system_info = function(opts)
    opts = opts or {}
    local tx, rx = u.oneshot_channel(
        opts.timeout or s.settings.max_timeout,
        opts.interval or s.settings.timeout_interval
    )

    fn.async.system_info(tx)
    local err1, err2, result = rx()
    return err1 or err2, result
end

--- Writes to a remote file
---
--- @param path string Path to the file to write
--- @param text string Text to write in the file
--- @param opts.timeout number Maximum time to wait for the program to finish
--- @param opts.interval number Time in milliseconds to wait between checks for program to finish
--- @return boolean result true if succeeded, otherwise false
fn.write_file_text = function(path, text, opts)
    opts = opts or {}
    local tx, rx = u.oneshot_channel(
        opts.timeout or s.settings.max_timeout,
        opts.interval or s.settings.timeout_interval
    )

    fn.async.write_file_text(path, text, tx)
    local err1, err2, result = rx()
    return err1 or err2, result
end

-------------------------------------------------------------------------------
-- ASYNC FUNCTIONS
-------------------------------------------------------------------------------

--- Creates a table in the form of {err, data} when given a response with
--- a singular payload entry
---
--- @param res? table The result in the form of {type = '...', data = {...}}
--- @param type_name string The type expected for the response
--- @param map? function A function that takes the data from a matching result
---        and returns a table in the form of {err, data}
--- @return table #The arguments to provide to a callback in form of {err, data}
local function make_args(res, type_name, map)
    assert(res == nil or type(res) == 'table')
    assert(type(type_name) == 'string')
    assert(map == nil or type(map) == 'function')
    map = map or function(data) return data end

    -- If we got a nil response for some reason, report it
    if res == nil then
        return 'Nil response received', nil
    -- If just expecting an ok type, we just return true
    elseif res.type == type_name and type_name == 'ok' then
        return false, map(true)
    -- For all other expected types, we return the payload data
    elseif res.type == type_name then
        return false, map(res.data)
    -- If we get an error type, return its description if it has one
    elseif res.type == 'error' and res.data and res.data.description then
        return res.data.description, nil
    -- Otherwise, if the error is returned but without a description, report it
    elseif res.type == 'error' and res.data then
        return 'Error response received without description', nil
    -- Otherwise, if the error is returned but without a payload, report it
    elseif res.type == 'error' then
        return 'Error response received without data payload', nil
    -- Otherwise, if we got an unexpected type, report it
    else
        return 'Received invalid response of type ' .. res.type, nil
    end
end

--- Contains async functions
fn.async = {}

--- Copies a remote file or directory to a new location
---
--- @param src string Path to the input file/directory to copy
--- @param dst string Path to the output file/directory
--- @param cb function Function that is passed true if successful or false if failed
fn.async.copy = function(src, dst, cb)
    assert(type(src) == 'string', 'src must be a string')
    assert(type(dst) == 'string', 'dst must be a string')

    s.client():send({
        type = 'copy';
        data = {
            src = src;
            dst = dst;
        };
    }, function(res)
        cb(make_args(res, 'ok'))
    end)
end

--- Retrieves a list of contents within a remote directory
---
--- @param path string Path to the directory whose contents to list
--- @param opts.depth number Will recursively retrieve all contents up to the specified depth
---        with 0 indicating that depth limit is unlimited
--- @param opts.absolute boolean If true, will return absolute paths instead of relative paths
--- @param opts.canonicalize boolean If true, will canonicalize paths, meaning following the
---        symlinks; note that to return absolute paths you must set the other option
--- @param opts.include_root boolean If true, will include the path provided as the root entry
---        in the response
--- @param cb function Function that is passed a list of entries in the form of
---           {'path' = ..., 'file_type' = ..., 'depth' = ...}
---           or nil if unsuccessful
fn.async.dir_list = function(path, opts, cb)
    assert(type(path) == 'string', 'path must be a string')
    opts = opts or {}

    s.client():send({
        type = 'dir_read';
        data = {
            path = path;
            depth = opts.depth or 1;
            absolute = opts.absolute or false;
            canonicalize = opts.canonicalize or false;
            include_root = opts.include_root or false;
        };
    }, function(res)
        cb(make_args(res, 'dir_entries', function(data)
            return data.entries
        end))
    end)
end

--- Checks whether or not the provided path exists on the remote machine
---
--- @param path string Path to the file, directory, or symlink
--- @param cb function Function that is passed true if exists or false if does not
fn.async.exists = function(path, cb)
    assert(type(path) == 'string', 'path must be a string')

    s.client():send({
        type = 'exists';
        data = { path = path };
    }, function(res)
        cb(make_args(res, 'exists'))
    end)
end

--- Retrieves filesystem metadata about a remote file, directory, or symlink
---
--- @param path string Path to the file, directory, or symlink
--- @param opts.canonicalize boolean If true, includes a canonicalized version
---        of the path in the response
--- @param opts.resolve_file_type boolean If true, resolves symlink file type
---        to the underlying dir or file type instead
--- @param cb function Function that is passed a table in the following format
---        where `accessed`, `created`, `modified`, and `canonicalized_path` are
---        optional and may be missing from the table
--
---         {
---             canonicalized_path = "...";
---             file_type = "dir|file|sym_link";
---             len = 1234;
---             readonly = true;
---             accessed = 1234;
---             created = 1234;
---             modified = 1234;
---         }
---
---        `len` is total bytes of file. `accessed`, `created`, and `modified` are
---        all in terms in milliseconds since UNIX epoch. If failed, nil will be
---        passed instead.
fn.async.metadata = function(path, opts, cb)
    assert(type(path) == 'string', 'path must be a string')
    opts = opts or {}

    s.client():send({
        type = 'metadata';
        data = {
            path = path;
            canonicalize = opts.canonicalize or false;
            resolve_file_type = opts.resolve_file_type or false;
        };
    }, function(res)
        cb(make_args(res, 'metadata', function(data)
            if data.canonicalized_path == vim.NIL then
                data.canonicalized_path = nil
            end
            return data
        end))
    end)
end

--- Creates a remote directory
---
--- @param path string Path to the directory to create
--- @param opts.all boolean If true, will recursively all components of path to directory
--- @param cb function Function that is passed true if successful or false if failed
fn.async.mkdir = function(path, opts, cb)
    assert(type(path) == 'string', 'path must be a string')
    opts = opts or {}
    opts.all = not (not opts.all)

    s.client():send({
        type = 'dir_create';
        data = {
            path = path;
            all = opts.all;
        };
    }, function(res)
        cb(make_args(res, 'ok'))
    end)
end

--- Reads a remote file as text
---
--- @param path string Path to the file to read
--- @param cb function Function that is passed file's text or nil if failed
fn.async.read_file_text = function(path, cb)
    assert(type(path) == 'string', 'path must be a string')

    s.client():send({
        type = 'file_read_text';
        data = { path = path };
    }, function(res)
        cb(make_args(res, 'text', function(data)
            return data.data
        end))
    end)
end

--- Removes a remote file or directory
---
--- @param path string Path to the file or directory to create
--- @param opts.force boolean If true, will remove directories that are non-empty
--- @param cb function Function that is passed true if successful or false if failed
fn.async.remove = function(path, opts, cb)
    assert(type(path) == 'string', 'path must be a string')
    opts = opts or {}
    opts.force = not (not opts.force)

    s.client():send({
        type = 'remove';
        data = {
            path = path;
            force = opts.force;
        };
    }, function(res)
        cb(make_args(res, 'ok'))
    end)
end

--- Renames a remote file or directory
---
--- @param src string Path to the file or directory to rename
--- @param dst string Path to the new file or directory
--- @param cb function Function that is passed true if successful or false if failed
fn.async.rename = function(src, dst, cb)
    assert(type(src) == 'string', 'src must be a string')
    assert(type(dst) == 'string', 'dst must be a string')

    s.client():send({
        type = 'rename';
        data = {
            src = src;
            dst = dst;
        };
    }, function(res)
        cb(make_args(res, 'ok'))
    end)
end

--- Executes a remote program
---
--- @param cmd string Name of the command to run
--- @param args list Array of arguments to append to the command
--- @param cb function Function that is passed table with code, stdout,
---        and stderr fields where stdout and stderr are lists of individual
---        lines of output, or nil if timeout
fn.async.run = function(cmd, args, cb)
    assert(type(cmd) == 'string', 'cmd must be a string')
    args = args or {}

    -- Make callback that can only be run once
    local has_called = false
    local wrapped_cb = function(...)
        if not has_called then
            has_called = true
            return cb(...)
        end
    end

    local function make_data(code, data)
        return {
            code = code;
            stdout = vim.tbl_flatten(u.filter_map(data, function(item)
                if item.type == 'proc_stdout' then
                    local text = item.data.data
                    if type(text) == 'string' then
                        text = vim.split(text, '\n', true)
                    end
                    return text
                end
            end));
            stderr = vim.tbl_flatten(u.filter_map(data, function(item)
                if item.type == 'proc_stderr' then
                    local text = item.data.data
                    if type(text) == 'string' then
                        text = vim.split(text, '\n', true)
                    end
                    return text
                end
            end));
        }
    end

    local function make_exit_code(msg)
        local code = msg.data.code
        if code == nil then
            if msg.data.success then
                code = 0
            else
                code = -1
            end
        end
        return code
    end

    -- Register a callback to receive stdout/stderr/done messages
    --
    -- At this point, we don't know the id of the process; so, we
    -- have to store all messages until we do
    local proc_id = nil
    local tmp = {}
    local broadcast_id = s.client():register_broadcast(function(msgs, unregister)
        if not vim.tbl_islist(msgs) then
            msgs = {msgs}
        end

        for _, msg in pairs(msgs) do
            if (
                msg.type == 'proc_done' or
                msg.type == 'proc_stdout' or
                msg.type == 'proc_stderr'
            ) then
                if proc_id == nil or proc_id == msg.data.id then
                    table.insert(tmp, msg)
                    if proc_id and msg.type == 'proc_done' then
                        unregister()
                        wrapped_cb(false, make_data(make_exit_code(msg), tmp))
                    end
                end
            end
        end
    end)

    s.client():send({
        type = 'proc_run';
        data = {
            cmd = cmd;
            args = args;
        };
    }, function(res)
        if res ~= nil and res.type == 'proc_start' then
            -- Now that we finally have the process id, we can scan all existing
            -- messages to see if we have a finished process
            proc_id = res.data.id

            -- It is now safe to filter out all of our messages
            tmp = u.filter_map(tmp, function(item)
                if item.data.id == proc_id then
                    return item
                else
                    return nil
                end
            end)

            -- Check if we already have an exit message
            local done = u.find(tmp, function(item)
                return item.type == 'proc_done'
            end)

            -- If we already have the result, stop the broadcast and return it
            if done then
                s.client():unregister_broadcast(broadcast_id)
                wrapped_cb(false, make_data(make_exit_code(done), tmp))
            end
        else
            -- Didn't get a proc_start, so stop our broadcast
            s.client():unregister_broadcast(broadcast_id)

            wrapped_cb(make_args(res, 'proc_start'))
        end
    end)
end

--- Requests information about the remote system
---
--- @param cb function Function that is passed a table with family, os, arch, current_dir,
---        and main_separator; or nil if failed
fn.async.system_info = function(cb)
    s.client():send({
        type = 'system_info';
        data = {[vim.type_idx] = vim.types.dictionary};
    }, function(res)
        cb(make_args(res, 'system_info'))
    end)
end

--- Writes to a remote file
---
--- @param path string Path to the file to write
--- @param text string Text to write in the file
--- @param cb function Function that is passed true if successful or false if failed
fn.async.write_file_text = function(path, text, cb)
    assert(type(path) == 'string', 'path must be a string')
    assert(type(text) == 'string', 'text must be a string')

    s.client():send({
        type = 'file_write_text';
        data = {
            path = path;
            text = text;
        };
    }, function(res)
        cb(make_args(res, 'ok'))
    end)
end

return fn
