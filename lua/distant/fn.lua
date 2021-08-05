local g = require('distant.internal.globals')
local u = require('distant.internal.utils')

local fn = {}

--- Copies a remote file or directory to a new location
---
--- @param src string Path to the input file/directory to copy
--- @param dst string Path to the output file/directory
--- @param timeout number Maximum time to wait for a response
--- @param interval number Time in milliseconds to wait between checks for a response
--- @return boolean result true if succeeded, otherwise false
fn.copy = function(src, dst, timeout, interval)
    local channel = u.oneshot_channel(
        timeout or g.settings.max_timeout,
        interval or g.settings.timeout_interval
    )

    fn.async.copy(src, dst, channel.tx)
    return channel.rx()
end

--- Retrieves a list of contents within a remote directory
---
--- @param path string Path to the directory whose contents to list
--- @param depth number Will recursively retrieve all contents up to the specified depth
---        with 0 indicating that depth limit is unlimited 
--- @param absolute boolean If true, will return absolute paths instead of relative paths
--- @param canonicalize boolean If true, will canonicalize paths, meaning following the
---        symlinks; note that to return absolute paths you must set the other option
--- @param timeout number Maximum time to wait for a response
--- @param interval number Time in milliseconds to wait between checks for a response
--- @return table entries A list of entries in the form of
---         {'path' = ..., 'file_type' = ..., 'depth' = ...}
---         or nil if unsuccessful
fn.dir_list = function(path, depth, absolute, canonicalize, timeout, interval)
    local channel = u.oneshot_channel(
        timeout or g.settings.max_timeout,
        interval or g.settings.timeout_interval
    )

    fn.async.dir_list(path, depth, absolute, canonicalize, channel.tx)
    return channel.rx()
end

--- Retrieves filesystem metadata about a remote file, directory, or symlink
---
--- @param path string Path to the file, directory, or symlink
--- @param timeout number Maximum time to wait for a response
--- @param interval number Time in milliseconds to wait between checks for a response
--- @return table metadata Table in the following format where `accessed`, `created`, 
---         and `modified` are optional and may be missing from the table
--
---         { 
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
fn.metadata = function(path, timeout, interval)
    local channel = u.oneshot_channel(
        timeout or g.settings.max_timeout,
        interval or g.settings.timeout_interval
    )

    fn.async.metadata(path, channel.tx)
    return channel.rx()
end

--- Creates a remote directory
---
--- @param path string Path to the directory to create
--- @param all boolean If true, will recursively all components of path to directory
--- @param timeout number Maximum time to wait for a response
--- @param interval number Time in milliseconds to wait between checks for a response
--- @return boolean result true if succeeded, otherwise false
fn.mkdir = function(path, all, timeout, interval)
    local channel = u.oneshot_channel(
        timeout or g.settings.max_timeout,
        interval or g.settings.timeout_interval
    )

    fn.async.mkdir(path, all, channel.tx)
    return channel.rx()
end

--- Reads a remote file as text
---
--- @param path string Path to the file to read
--- @param timeout number Maximum time to wait for a response
--- @param interval number Time in milliseconds to wait between checks for a response
--- @return string text file's text, or nil if fails
fn.read_file_text = function(path, timeout, interval)
    local channel = u.oneshot_channel(
        timeout or g.settings.max_timeout,
        interval or g.settings.timeout_interval
    )

    fn.async.read_file_text(path, channel.tx)
    return channel.rx()
end

--- Removes a remote file or directory
---
--- @param path string Path to the file or directory to create
--- @param force boolean If true, will remove directories that are non-empty
--- @param timeout number Maximum time to wait for a response
--- @param interval number Time in milliseconds to wait between checks for a response
--- @return boolean result true if succeeded, otherwise false
fn.remove = function(path, force, timeout, interval)
    local channel = u.oneshot_channel(
        timeout or g.settings.max_timeout,
        interval or g.settings.timeout_interval
    )

    fn.async.remove(path, force, channel.tx)
    return channel.rx()
end

--- Renames a remote file or directory
---
--- @param src string Path to the file or directory to rename
--- @param dst string Path to the new file or directory
--- @param timeout number Maximum time to wait for a response
--- @param interval number Time in milliseconds to wait between checks for a response
--- @return boolean result true if succeeded, otherwise false
fn.rename = function(src, dst, timeout, interval)
    local channel = u.oneshot_channel(
        timeout or g.settings.max_timeout,
        interval or g.settings.timeout_interval
    )

    fn.async.rename(src, dst, channel.tx)
    return channel.rx()
end

--- Executes a remote program
---
--- @param cmd string Name of the command to run
--- @param args list Array of arguments to append to the command
--- @param timeout number Maximum time to wait for the program to finish
--- @param interval number Time in milliseconds to wait between checks for program to finish
--- @return table output Table with exit_code, stdout, and stderr fields where 
---         stdout and stderr are lists of individual lines of output, or
---         returns nil if timeout
fn.run = function(cmd, args, timeout, interval)
    local channel = u.oneshot_channel(
        timeout or g.settings.max_timeout,
        interval or g.settings.timeout_interval
    )

    fn.async.run(cmd, args, channel.tx)
    return channel.rx()
end

--- Writes to a remote file
---
--- @param path string Path to the file to write
--- @param text string Text to write in the file
--- @return boolean result true if succeeded, otherwise false
fn.write_file_text = function(path, text)
    local channel = u.oneshot_channel(
        timeout or g.settings.max_timeout,
        interval or g.settings.timeout_interval
    )

    fn.async.write_file_text(path, text, channel.tx)
    return channel.rx()
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

    g.client():send({
        type = 'copy';
        data = {
            src = src;
            dst = dst;
        };
    }, function(res)
        cb(res ~= nil and res.type == 'ok')
    end)
end

--- Retrieves a list of contents within a remote directory
---
--- @param path string Path to the directory whose contents to list
--- @param depth number Will recursively retrieve all contents up to the specified depth
---        with 0 indicating that depth limit is unlimited 
--- @param absolute boolean If true, will return absolute paths instead of relative paths
--- @param canonicalize boolean If true, will canonicalize paths, meaning following the
---        symlinks; note that to return absolute paths you must set the other option
--- @param cb function Function that is passed a list of entries in the form of
---           {'path' = ..., 'file_type' = ..., 'depth' = ...}
---           or nil if unsuccessful
fn.async.dir_list = function(path, depth, absolute, canonicalize, cb)
    assert(type(path) == 'string', 'path must be a string')
    assert(type(depth) == 'number' and depth >= 0, 'depth must be a number >= 0')
    assert(type(absolute) == 'boolean', 'absolute must be a boolean')
    assert(type(canonicalize) == 'boolean', 'canonicalize must be a boolean')

    g.client():send({
        type = 'dir_read';
        data = {
            path = path;
            depth = depth;
            absolute = absolute;
            canonicalize = canonicalize;
        };
    }, function(res)
        if res ~= nil and res.type == 'dir_entries' then
            cb(res.data.entries)
        else
            cb(nil)
        end
    end)
end

--- Retrieves filesystem metadata about a remote file, directory, or symlink
---
--- @param path string Path to the file, directory, or symlink
--- @param cb function Function that is passed a table in the following format
---        where `accessed`, `created`, and `modified` are optional and may be
---        missing from the table
--
---         { 
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
fn.async.metadata = function(path, cb)
    assert(type(path) == 'string', 'path must be a string')

    g.client():send({
        type = 'metadata';
        data = { path = path };
    }, function(res)
        if res ~= nil and res.type == 'metadata' then
            cb(res.data.data)
        else
            cb(nil)
        end
    end)
end

--- Creates a remote directory
---
--- @param path string Path to the directory to create
--- @param all boolean If true, will recursively all components of path to directory
--- @param cb function Function that is passed true if successful or false if failed
fn.async.mkdir = function(path, all, cb)
    assert(type(path) == 'string', 'path must be a string')
    all = not (not all)

    g.client():send({
        type = 'dir_create';
        data = {
            path = path;
            all = all;
        };
    }, function(res)
        cb(res ~= nil and res.type == 'ok')
    end)
end

--- Reads a remote file as text
---
--- @param path string Path to the file to read
--- @param cb function Function that is passed file's text or nil if failed
fn.async.read_file_text = function(path, cb)
    assert(type(path) == 'string', 'path must be a string')

    g.client():send({
        type = 'file_read_text';
        data = { path = path };
    }, function(res)
        if res ~= nil and res.type == 'text' then
            cb(res.data.data)
        else
            cb(nil)
        end
    end)
end

--- Removes a remote file or directory
---
--- @param path string Path to the file or directory to create
--- @param force boolean If true, will remove directories that are non-empty
--- @param cb function Function that is passed true if successful or false if failed
fn.async.remove = function(path, force, cb)
    assert(type(path) == 'string', 'path must be a string')
    force = not (not force)

    g.client():send({
        type = 'remove';
        data = {
            path = path;
            force = force;
        };
    }, function(res)
        cb(res ~= nil and res.type == 'ok')
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

    g.client():send({
        type = 'rename';
        data = {
            src = src;
            dst = dst;
        };
    }, function(res)
        cb(res ~= nil and res.type == 'ok')
    end)
end

--- Executes a remote program
---
--- @param cmd string Name of the command to run
--- @param args list Array of arguments to append to the command
--- @param cb function Function that is passed table with exit_code, stdout,
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

    local function make_res(exit_code, data)
        return {
            exit_code = exit_code;
            stdout = u.filter_map(data, function(item)
                if item.type == 'proc_stdout' then
                    return item.data.data
                end
            end);
            stderr = u.filter_map(data, function(item)
                if item.type == 'proc_stderr' then
                    return item.data.data
                end
            end);
        }
    end

    local function make_exit_code(msg)
        local exit_code = msg.data.exit_code
        if exit_code == nil then
            if msg.data.success then
                exit_code = 0
            else
                exit_code = -1
            end
        end
    end

    -- Register a callback to receive stdout/stderr/done messages
    --
    -- At this point, we don't know the id of the process; so, we
    -- have to store all messages until we do
    local proc_id = nil
    local tmp = {}
    local broadcast_id = g.client():register_broadcast(function(msg, unregister)
        if (
            msg.type == 'proc_done' or
            msg.type == 'proc_stdout' or
            msg.type == 'proc_stderr'
        ) then
            if proc_id == nil or proc_id == msg.data.id then
                table.insert(tmp, msg)
                if proc_id and msg.type == 'proc_done' then
                    unregister()
                    wrapped_cb(make_res(make_exit_code(msg), tmp))
                end
            end
        end
    end)

    g.client():send({
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
                if item.id == proc_id then
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
                g.client():unregister_broadcast(broadcast_id)
                wrapped_cb(make_res(make_exit_code(done), tmp))
            end
        else
            wrapped_cb(nil)
        end
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

    g.client():send({
        type = 'file_write_text';
        data = { 
            path = path;
            text = text;
        };
    }, function(res)
        cb(res ~= nil and res.type == 'ok')
    end)
end

return fn
