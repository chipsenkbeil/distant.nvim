local Process = require('distant-core.cli.client.api.process')
local Search = require('distant-core.cli.client.api.search')
local Transport = require('distant-core.cli.client.transport')
local log = require('distant-core.log')

--- @class DistantApiError
--- @field kind string
--- @field description string

--- @alias DistantApiErrorKind
--- | '"not_found"' # An entity was not found, often a file
--- | '"permission_denied"' # The operation lacked the necessary privileges to complete
--- | '"connection_refused"' # The connection was refused by the remote server
--- | '"connection_reset"' # The connection was reset by the remote server
--- | '"connection_aborted"' # The connection was aborted (terminated) by the remote server
--- | '"not_connected"' # The network operation failed because it was not connected yet
--- | '"addr_in_use"' # A socket address could not be bound because the address is already in use elsewhere
--- | '"addr_not_available"' # A nonexistent interface was requested or the requested address was not local
--- | '"broken_pipe"' # The operation failed because a pipe was closed
--- | '"already_exists"' # An entity already exists, often a file
--- | '"would_block"' # The operation needs to block to complete, but the blocking operation was requested to not occur
--- | '"invalid_input"' # A parameter was incorrect
--- | '"invalid_data"' # Data not valid for the operation were encountered
--- | '"timed_out"' # The I/O operation's timeout expired, causing it to be cancelled
--- | '"write_zero"' # An error returned when an operation could not be completed because a call to `write` returned `Ok(0)`
--- | '"interrupted"' # This operation was interrupted
--- | '"other"' # Any I/O error not part of this list
--- | '"unexpected_eof"' # An error returned when an operation could not be completed because an "end of file" was reached prematurely
--- | '"unsupported"' # This operation is unsupported on this platform
--- | '"out_of_memory"' # An operation could not be completed, because it failed to allocate enough memory
--- | '"loop"' # When a loop is encountered when walking a directory
--- | '"task_cancelled"' # When a task is cancelled
--- | '"task_panicked"' # When a task panics
--- | '"unknown"' # Catchall for an error that has no specific type

--- Represents an API that uses a transport to communicate payloads.
--- @class DistantApi
--- @field transport DistantApiTransport
local M = {}
M.__index = M

--- @param opts {binary:string, network:DistantClientNetwork, auth_handler?:AuthHandler, timeout?:number, interval?:number}
--- @return DistantApi
function M:new(opts)
    local instance = {}
    setmetatable(instance, M)
    instance.transport = Transport:new(opts)

    return instance
end

function M:start()
    self.transport:start(function(exit_code)
        log.fmt_debug('API process exited: %s', exit_code)
    end)
end

function M:stop()
    self.transport:stop()
end

local function verify_ok(payload)
    return type(payload) == 'table' and payload.type == 'ok'
end

--- @param opts {path:string, data:table, timeout?:number, interval?:number}
--- @param cb fun(err?:string, payload?:{type:'ok'})
function M:append_file(opts, cb)
    vim.validate({
        opts = { opts, 'table' },
        cb = { cb, 'function', true },
    })

    return self.transport:send({
        payload = {
            type = 'file_append',
            path = opts.path,
            data = opts.data,
        },
        cb = cb,
        verify = verify_ok,
        timeout = opts.timeout,
        interval = opts.interval,
    })
end

--- @param opts {path:string, text:string, timeout?:number, interval?:number}
--- @param cb fun(err?:string, payload?:{type:'ok'})
function M:append_file_text(opts, cb)
    vim.validate({
        opts = { opts, 'table' },
        cb = { cb, 'function', true },
    })

    return self.transport:send({
        payload = {
            type = 'file_append_text',
            path = opts.path,
            text = opts.text,
        },
        cb = cb,
        verify = verify_ok,
        timeout = opts.timeout,
        interval = opts.interval,
    })
end

--- @param opts {timeout?:number, interval?:number}
--- @param cb fun(err?:string, payload?:{type:'capabilities', supported:string[]})
function M:capabilities(opts, cb)
    vim.validate({
        opts = { opts, 'table' },
        cb = { cb, 'function', true },
    })

    return self.transport:send({
        payload = {
            type = 'capabilities',
        },
        cb = cb,
        verify = function(payload)
            return (
                payload.type == 'capabilities'
                and type(payload.supported) == 'table'
                and vim.tbl_islist(payload.supported))
        end,
        timeout = opts.timeout,
        interval = opts.interval,
    })
end

--- @param opts {src:string, dst:string, timeout?:number, interval?:number}
--- @param cb fun(err?:string, payload?:{type:'ok'})
function M:copy(opts, cb)
    vim.validate({
        opts = { opts, 'table' },
        cb = { cb, 'function', true },
    })

    return self.transport:send({
        payload = {
            type = 'copy',
            src = opts.src,
            dst = opts.dst,
        },
        cb = cb,
        verify = verify_ok,
        timeout = opts.timeout,
        interval = opts.interval,
    })
end

--- @param opts {path:string, all?:boolean, timeout?:number, interval?:number}
--- @param cb fun(err?:string, payload?:{type:'ok'})
function M:create_dir(opts, cb)
    vim.validate({
        opts = { opts, 'table' },
        cb = { cb, 'function', true },
    })

    return self.transport:send({
        payload = {
            type = 'dir_create',
            path = opts.path,
            all = opts.all,
        },
        cb = cb,
        verify = verify_ok,
        timeout = opts.timeout,
        interval = opts.interval,
    })
end

--- @param opts {path:string, timeout?:number, interval?:number}
--- @param cb fun(err?:string, payload?:boolean)
function M:exists(opts, cb)
    vim.validate({
        opts = { opts, 'table' },
        cb = { cb, 'function', true },
    })

    return self.transport:send({
        payload = {
            type = 'exists',
            path = opts.path,
        },
        cb = cb,
        verify = verify_ok,
        map = function(payload) return payload.value end,
        timeout = opts.timeout,
        interval = opts.interval,
    })
end

--- @class DistantApiMetadataResponse
--- @field type 'metadata'
--- @field canonicalized_path? string
--- @field file_type string
--- @field len number
--- @field readonly boolean
--- @field accessed? number
--- @field created? number
--- @field modified? number
--- @field unix? table
--- @field windows? table

--- @param opts {path:string, canonicalize?:boolean, resolve_file_type?:boolean, timeout?:number, interval?:number}
--- @param cb fun(err?:string, payload?:DistantApiMetadataResponse)
function M:metadata(opts, cb)
    vim.validate({
        opts = { opts, 'table' },
        cb = { cb, 'function', true },
    })

    return self.transport:send({
        payload = {
            type = 'metadata',
            path = opts.path,
            canonicalize = opts.canonicalize,
            resolve_file_type = opts.resolve_file_type,
        },
        cb = cb,
        verify = function(payload)
            return (
                payload.type == 'metadata'
                and type(payload.file_type) == 'string'
                and type(payload.len) == 'number'
                and type(payload.readonly) == 'boolean')
        end,
        timeout = opts.timeout,
        interval = opts.interval,
    })
end

--- @class DistantDirEntry
--- @field path string
--- @field file_type 'dir'|'file'|'symlink'
--- @field depth number

--- @param opts {path:string, depth?:number, absolute?:boolean, canonicalize?:boolean, include_root?:boolean, timeout?:number, interval?:number}
--- @param cb fun(err?:string, payload?:{type:'dir_entries', entries:DistantDirEntry[], errors:DistantApiError[]})
function M:read_dir(opts, cb)
    vim.validate({
        opts = { opts, 'table' },
        cb = { cb, 'function', true },
    })

    return self.transport:send({
        payload = {
            type = 'dir_read',
            path = opts.path,
            depth = opts.depth,
            absolute = opts.absolute,
            canonicalize = opts.canonicalize,
            include_root = opts.include_root,
        },
        cb = cb,
        verify = function(payload)
            return payload.type == 'dir_entries' and vim.tbl_islist(payload.entries) and vim.tbl_islist(payload.errors)
        end,
        timeout = opts.timeout,
        interval = opts.interval,
    })
end

--- @param opts {path:string, timeout?:number, interval?:number}
--- @param cb fun(err?:string, payload?:number[])
function M:read_file(opts, cb)
    vim.validate({
        opts = { opts, 'table' },
        cb = { cb, 'function', true },
    })

    return self.transport:send({
        payload = {
            type = 'file_read',
            path = opts.path,
        },
        cb = cb,
        verify = function(payload)
            return payload.type == 'blob' and vim.tbl_islist(payload.data)
        end,
        map = function(payload) return payload.data end,
        timeout = opts.timeout,
        interval = opts.interval,
    })
end

--- @param opts {path:string, timeout?:number, interval?:number}
--- @param cb fun(err?:string, payload?:string)
function M:read_file_text(opts, cb)
    vim.validate({
        opts = { opts, 'table' },
        cb = { cb, 'function', true },
    })

    return self.transport:send({
        payload = {
            type = 'file_read_text',
            path = opts.path,
        },
        cb = cb,
        verify = function(payload)
            return payload.type == 'text' and type(payload.data) == 'string'
        end,
        map = function(payload) return payload.data end,
        timeout = opts.timeout,
        interval = opts.interval,
    })
end

--- @param opts {path:string, force?:boolean, timeout?:number, interval?:number}
--- @param cb fun(err?:string, payload?:{type:'ok'})
function M:remove(opts, cb)
    vim.validate({
        opts = { opts, 'table' },
        cb = { cb, 'function', true },
    })

    return self.transport:send({
        payload = {
            type = 'remove',
            path = opts.path,
            force = opts.force,
        },
        cb = cb,
        verify = verify_ok,
        timeout = opts.timeout,
        interval = opts.interval,
    })
end

--- @param opts {src:string, dst:string, timeout?:number, interval?:number}
--- @param cb fun(err?:string, payload?:{type:'ok'})
function M:rename(opts, cb)
    vim.validate({
        opts = { opts, 'table' },
        cb = { cb, 'function', true },
    })

    return self.transport:send({
        payload = {
            type = 'remove',
            src = opts.src,
            dst = opts.dst,
        },
        cb = cb,
        verify = verify_ok,
        timeout = opts.timeout,
        interval = opts.interval,
    })
end

--- @param opts {query:DistantApiSearchQuery, on_results?:fun(matches:DistantApiSearchMatch[]), timeout?:number, interval?:number}
--- @param cb fun(err?:string, matches?:DistantApiSearchMatch[])
--- @return string|nil, DistantApiSearch|DistantApiSearchMatch[]|nil
function M:search(opts, cb)
    vim.validate({
        opts = { opts, 'table' },
        cb = { cb, 'function', true },
    })

    local search = Search:new({
        transport = self.transport
    })

    if type(cb) == 'function' then
        -- Asynchronous, so we start executing and return the search so it can be canceled
        search:execute({
            query = opts.query,
            on_results = opts.on_results,
            timeout = opts.timeout,
            interval = opts.interval,
        }, cb)

        return nil, search
    else
        -- Synchronous, so we block while executing in order to return search results
        return search:execute({
            query = opts.query,
            on_results = opts.on_results,
            timeout = opts.timeout,
            interval = opts.interval,
        })
    end
end

--- @param opts DistantApiProcessSpawnOpts
--- @param cb? fun(err?:string, results?:DistantApiProcessSpawnResults)
--- @return string|nil, DistantApiProcess|DistantApiProcessSpawnResults|nil
function M:spawn(opts, cb)
    vim.validate({
        opts = { opts, 'table' },
        cb = { cb, 'function', true },
    })

    local process = Process:new({
        transport = self.transport
    })

    if type(cb) == 'function' then
        -- Asynchronous, so we start executing and return the process so it can be
        -- written to, killed, or have its pty resized
        process:spawn(opts, cb)

        return nil, process
    else
        -- Synchronous, so we block while executing in order to return results
        return process:spawn(opts)
    end
end

--- @param opts {timeout?:number, interval?:number}
--- @param cb fun(err?:string, payload?:{type:'system_info', family:string, os:string, arch:string, current_dir:string, main_separator:string})
function M:system_info(opts, cb)
    vim.validate({
        opts = { opts, 'table' },
        cb = { cb, 'function', true },
    })

    return self.transport:send({
        payload = {
            type = 'file_write_text',
        },
        cb = cb,
        verify = function(payload)
            return (
                payload.type == 'system_info'
                and type(payload.family) == 'string'
                and type(payload.os) == 'string'
                and type(payload.arch) == 'string'
                and type(payload.current_dir) == 'string'
                and type(payload.main_separator) == 'string'
                )
        end,
        timeout = opts.timeout,
        interval = opts.interval,
    })
end

--- @param opts {path:string, data:table, timeout?:number, interval?:number}
--- @param cb fun(err?:string, payload?:{type:'ok'})
function M:write_file(opts, cb)
    vim.validate({
        opts = { opts, 'table' },
        cb = { cb, 'function', true },
    })

    return self.transport:send({
        payload = {
            type = 'file_write',
            path = opts.path,
            data = opts.data,
        },
        cb = cb,
        verify = verify_ok,
        timeout = opts.timeout,
        interval = opts.interval,
    })
end

--- @param opts {path:string, text:string, timeout?:number, interval?:number}
--- @param cb fun(err?:string, payload?:{type:'ok'})
function M:write_file_text(opts, cb)
    vim.validate({
        opts = { opts, 'table' },
        cb = { cb, 'function', true },
    })

    return self.transport:send({
        payload = {
            type = 'file_write_text',
            path = opts.path,
            text = opts.text,
        },
        cb = cb,
        verify = verify_ok,
        timeout = opts.timeout,
        interval = opts.interval,
    })
end

--- @alias ChangeKind
--- | '"access"' # Something about a file or directory was accessed, but no specific details were known
--- | '"access_close_execute"' # A file was closed for executing
--- | '"access_close_read"' # A file was closed for reading
--- | '"access_close_write"' # A file was closed for writing
--- | '"access_open_execute"' # A file was opened for executing
--- | '"access_open_read"' # A file was opened for reading
--- | '"access_open_write"' # A file was opened for writing
--- | '"access_open"' # A file or directory was read
--- | '"access_time"' # The access time of a file or directory was changed
--- | '"create"' # A file, directory, or something else was created
--- | '"content"' # The content of a file or directory changed
--- | '"data"' # The data of a file or directory was modified, but no specific details were known
--- | '"metadata"' # The metadata of a file or directory was modified, but no specific details were known
--- | '"modify"' # Something about a file or directory was modified, but no specific details were known
--- | '"remove"' # A file, directory, or something else was removed
--- | '"rename"' # A file or directory was renamed, but no specific details were known
--- | '"rename_both"' # A file or directory was renamed, and the provided paths are the source and target in that order (from, to)
--- | '"rename_from"' # A file or directory was renamed, and the provided path is the origin of the rename (before being renamed)
--- | '"rename_to"' # A file or directory was renamed, and the provided path is the result of the rename
--- | '"size"' # A file's size changed
--- | '"ownership"' # The ownership of a file or directory was changed
--- | '"permissions"' # The permissions of a file or directory was changed
--- | '"write_time"' # The write or modify time of a file or directory was changed
--- | '"unknown"' # Catchall in case we have no insight as to the type of change

--- Begins watching a path for changes.
---
--- NOTE: This function does NOT have a synchronous equivalent!
---
--- @param opts {path:string, recursive?:boolean, only?:ChangeKind[], except?:ChangeKind[], timeout?:number, interval?:number}
--- @param cb fun(err?:string, payload?:{type:'changed', kind:ChangeKind, paths:string[]})
function M:watch(opts, cb)
    vim.validate({
        opts = { opts, 'table' },
        cb = { cb, 'function' },
    })

    return self.transport:send({
        payload = {
            type = 'watch',
            path = opts.path,
            recursive = opts.recursive,
            only = opts.only,
            except = opts.except,
        },
        cb = cb,
        verify = verify_ok,
        more = function(payload)
            -- NOTE: First response to watch is "ok", so we need
            --       to allow that alongside changed events.
            -- TODO: This will send a callback of "ok" first before
            --       ever triggering a watch! We need to create
            --       a watch first!
            return payload.type == 'changed' or payload.type == 'ok'
        end,
        timeout = opts.timeout,
        interval = opts.interval,
    })
end

--- @param opts {path:string, timeout?:number, interval?:number}
--- @param cb fun(err?:string, payload?:{type:'ok'})
function M:unwatch(opts, cb)
    vim.validate({
        opts = { opts, 'table' },
        cb = { cb, 'function', true },
    })

    return self.transport:send({
        payload = {
            type = 'unwatch',
            path = opts.path,
        },
        cb = cb,
        verify = verify_ok,
        timeout = opts.timeout,
        interval = opts.interval,
    })
end

return M
