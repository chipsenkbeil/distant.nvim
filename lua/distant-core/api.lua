local Batch = require('distant-core.api.batch')
local Error = require('distant-core.api.error')
local Process = require('distant-core.api.process')
local Searcher = require('distant-core.api.searcher')
local Transport = require('distant-core.api.transport')

local log = require('distant-core.log')

--- Represents an API that uses a transport to communicate payloads.
--- @class distant.core.Api
--- @field private transport distant.core.api.Transport
local M = {}
M.__index = M

--- @param opts {binary:string, network?:distant.core.client.Network, auth_handler?:distant.core.auth.Handler, timeout?:number, interval?:number}
--- @return distant.core.Api
function M:new(opts)
    local instance = {}
    setmetatable(instance, M)
    instance.transport = Transport:new({
        autostart = true,
        binary = opts.binary,
        network = opts.network,
        auth_handler = opts.auth_handler,
        timeout = opts.timeout,
        interval = opts.interval,
    })

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

--- Sends a series of API requests together as a single batch.
---
--- * `batch_fn` - invoked to build up batch request and return results.
---   The function is provided an API wrapper that queues up each request
---   rather than submitting directly.
---
--- ```
---
--  -- Run synchronously
--- local results = api.batch(function(api)
---     return {
---         api.exists({ path = '/path/to/file1.txt }),
---         api.exists({ path = '/path/to/file2.txt }),
---         api.metadata({ path = '/path/to/file3.txt }),
---         api.system_info({}),
---     }
--- end)
---
--- -- { payload = true }
--- print(vim.inspect(results[1]))
---
--- -- { payload = false }
--- print(vim.inspect(results[2]))
---
--- -- { err = distant.api.Error { .. } }
--- print(vim.inspect(results[2]))
---
--- -- { payload = { family = 'unix', .. } }
--- print(vim.inspect(results[2]))
--- ```
---
--- @generic T: table
--- @param batch_fn fun(batch:distant.core.api.Batch):distant.core.api.batch.PartialRequest[]
--- @param cb? fun(results:{err?:distant.core.api.Error, payload?:table}[])
--- @return {err?:distant.core.api.Error, payload?:table}[]|nil
function M:batch(batch_fn, cb)
    local batch = Batch:new(self)
    local partial_requests = batch_fn(batch)

    if cb then
    else
    end
end

--- @alias distant.core.api.OkPayload {type:'ok'}
--- @param payload distant.core.api.OkPayload
local function verify_ok(payload)
    return type(payload) == 'table' and payload.type == 'ok'
end

--- @alias distant.core.api.AppendFileOpts {path:string, data:integer[], timeout?:number, interval?:number}
--- @param opts distant.core.api.AppendFileOpts
--- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.OkPayload)
--- @return distant.core.api.Error|nil,distant.core.api.OkPayload|nil
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
        verify = verify_ok,
        timeout = opts.timeout,
        interval = opts.interval,
    }, cb)
end

--- @alias distant.core.api.AppendFileTextOpts {path:string, text:string, timeout?:number, interval?:number}
--- @param opts distant.core.api.AppendFileTextOpts
--- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.OkPayload)
--- @return distant.core.api.Error|nil,distant.core.api.OkPayload|nil
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
        verify = verify_ok,
        timeout = opts.timeout,
        interval = opts.interval,
    }, cb)
end

--- @alias distant.core.api.CapabilitiesOpts {timeout?:number, interval?:number}
--- @alias distant.core.api.CapabilitiesPayload {type:'capabilities', supported:string[]}
--- @param opts distant.core.api.CapabilitiesOpts
--- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.CapabilitiesPayload)
--- @return distant.core.api.Error|nil,distant.core.api.CapabilitiesPayload|nil
function M:capabilities(opts, cb)
    vim.validate({
        opts = { opts, 'table' },
        cb = { cb, 'function', true },
    })

    return self.transport:send({
        payload = {
            type = 'capabilities',
        },
        verify = function(payload)
            return (
                payload.type == 'capabilities'
                and type(payload.supported) == 'table'
                and vim.tbl_islist(payload.supported))
        end,
        timeout = opts.timeout,
        interval = opts.interval,
    }, cb)
end

--- @alias distant.core.api.CopyOpts {src:string, dst:string, timeout?:number, interval?:number}
--- @param opts distant.core.api.CopyOpts
--- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.OkPayload)
--- @return distant.core.api.Error|nil,distant.core.api.OkPayload|nil
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
        verify = verify_ok,
        timeout = opts.timeout,
        interval = opts.interval,
    }, cb)
end

--- @alias distant.core.api.CreateDirOpts {path:string, all?:boolean, timeout?:number, interval?:number}
--- @param opts distant.core.api.CreateDirOpts
--- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.OkPayload)
--- @return distant.core.api.Error|nil,distant.core.api.OkPayload|nil
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
        verify = verify_ok,
        timeout = opts.timeout,
        interval = opts.interval,
    }, cb)
end

--- @alias distant.core.api.ExistsOpts {path:string, timeout?:number, interval?:number}
--- @param opts distant.core.api.ExistsOpts
--- @param cb? fun(err?:distant.core.api.Error, payload?:boolean)
--- @return distant.core.api.Error|nil,boolean|nil
function M:exists(opts, cb)
    vim.validate({
        opts = { opts, 'table' },
        cb = { cb, 'function', true },
    })

    local err, value = self.transport:send({
        payload = {
            type = 'exists',
            path = opts.path,
        },
        verify = function(payload)
            return payload.type == 'exists'
        end,
        map = function(payload) return payload.value end,
        timeout = opts.timeout,
        interval = opts.interval,
    }, cb)

    --- @cast value -table, +boolean
    return err, value
end

--- @class distant.core.api.MetadataPayload
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

--- @class distant.core.api.MetadataOpts
--- @field path string
--- @field canonicalize? boolean
--- @field resolve_file_type? boolean
--- @field timeout? number
--- @field interval? number

--- @param opts distant.core.api.MetadataOpts
--- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.MetadataPayload)
--- @return distant.core.api.Error|nil,distant.core.api.MetadataPayload|nil
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
        verify = function(payload)
            return (
                payload.type == 'metadata'
                and type(payload.file_type) == 'string'
                and type(payload.len) == 'number'
                and type(payload.readonly) == 'boolean')
        end,
        timeout = opts.timeout,
        interval = opts.interval,
    }, cb)
end

--- @class distant.core.api.DirEntry
--- @field path string
--- @field file_type 'dir'|'file'|'symlink'
--- @field depth number

--- @class distant.core.api.ReadDirOpts
--- @field path string
--- @field depth? number
--- @field absolute? boolean
--- @field canonicalize? boolean
--- @field include_root? boolean
--- @field timeout? number
--- @field interval? number

--- @class distant.core.api.ReadDirPayload
--- @field type 'dir_entries'
--- @field entries distant.core.api.DirEntry[]
--- @field errors distant.core.api.Error[]

--- @param opts distant.core.api.ReadDirOpts
--- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.ReadDirPayload)
--- @return distant.core.api.Error|nil,distant.core.api.ReadDirPayload|nil
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
        verify = function(payload)
            return payload.type == 'dir_entries' and vim.tbl_islist(payload.entries) and vim.tbl_islist(payload.errors)
        end,
        map = function(payload)
            return {
                entries = payload.entries,
                errors = vim.tbl_map(function(e) return Error:new(e) end, payload.errors),
            }
        end,
        timeout = opts.timeout,
        interval = opts.interval,
    }, cb)
end

--- @alias distant.core.api.ReadFileOpts {path:string, timeout?:number, interval?:number}
--- @param opts distant.core.api.ReadFileOpts
--- @param cb? fun(err?:distant.core.api.Error, payload?:number[])
--- @return distant.core.api.Error|nil,number[]|nil
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
        verify = function(payload)
            return payload.type == 'blob' and vim.tbl_islist(payload.data)
        end,
        map = function(payload) return payload.data end,
        timeout = opts.timeout,
        interval = opts.interval,
    }, cb)
end

--- @alias distant.core.api.ReadFileTextOpts {path:string, timeout?:number, interval?:number}
--- @param opts distant.core.api.ReadFileTextOpts
--- @param cb? fun(err?:distant.core.api.Error, payload?:string)
--- @return distant.core.api.Error|nil,string|nil
function M:read_file_text(opts, cb)
    vim.validate({
        opts = { opts, 'table' },
        cb = { cb, 'function', true },
    })

    local err, value = self.transport:send({
        payload = {
            type = 'file_read_text',
            path = opts.path,
        },
        verify = function(payload)
            return payload.type == 'text' and type(payload.data) == 'string'
        end,
        map = function(payload) return payload.data end,
        timeout = opts.timeout,
        interval = opts.interval,
    }, cb)

    --- @cast value -table, +string
    return err, value
end

--- @alias distant.core.api.RemoveOpts {path:string, force?:boolean, timeout?:number, interval?:number}
--- @param opts distant.core.api.RemoveOpts
--- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.OkPayload)
--- @return distant.core.api.Error|nil,distant.core.api.OkPayload|nil
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
        verify = verify_ok,
        timeout = opts.timeout,
        interval = opts.interval,
    }, cb)
end

--- @alias distant.core.api.RenameOpts {src:string, dst:string, timeout?:number, interval?:number}
--- @param opts distant.core.api.RenameOpts
--- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.OkPayload)
--- @return distant.core.api.Error|nil,distant.core.api.OkPayload|nil
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
        verify = verify_ok,
        timeout = opts.timeout,
        interval = opts.interval,
    }, cb)
end

--- @class distant.core.api.SearchOpts
--- @field query distant.core.api.search.Query
--- @field on_results? fun(matches:distant.core.api.search.Match[])
--- @field on_start? fun(id:integer)
--- @field timeout? number
--- @field interval? number

--- @param opts distant.core.api.SearchOpts
--- @param cb? fun(err?:distant.core.api.Error, matches?:distant.core.api.search.Match[])
--- @return distant.core.api.Error|nil, distant.core.api.Searcher|distant.core.api.search.Match[]|nil
function M:search(opts, cb)
    vim.validate({
        opts = { opts, 'table' },
        cb = { cb, 'function', true },
    })

    local searcher = Searcher:new({
        transport = self.transport
    })

    if type(cb) == 'function' then
        -- Asynchronous, so we start executing and return the search so it can be canceled
        searcher:execute({
            query = opts.query,
            on_results = opts.on_results,
            on_start = opts.on_start,
            timeout = opts.timeout,
            interval = opts.interval,
        }, cb)

        return nil, searcher
    else
        -- Synchronous, so we block while executing in order to return search results
        return searcher:execute({
            query = opts.query,
            on_results = opts.on_results,
            on_start = opts.on_start,
            timeout = opts.timeout,
            interval = opts.interval,
        })
    end
end

--- @param opts distant.core.api.process.SpawnOpts
--- @param cb? fun(err?:distant.core.api.Error, results?:distant.core.api.process.SpawnResults)
--- @return distant.core.api.Error|nil, distant.core.api.Process|distant.core.api.process.SpawnResults|nil
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

--- @class distant.core.api.SystemInfoPayload
--- @field type 'system_info'
--- @field family string
--- @field os string
--- @field arch string
--- @field current_dir string
--- @field main_separator string
--- @field username string
--- @field shell string

--- @alias distant.core.api.SystemInfoOpts {timeout?:number, interval?:number}
--- @param opts distant.core.api.SystemInfoOpts
--- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.SystemInfoPayload)
--- @return distant.core.api.Error|nil,distant.core.api.SystemInfoPayload|nil
function M:system_info(opts, cb)
    vim.validate({
        opts = { opts, 'table' },
        cb = { cb, 'function', true },
    })

    return self.transport:send({
        payload = {
            type = 'system_info',
        },
        verify = function(payload)
            return (
                payload.type == 'system_info'
                and type(payload.family) == 'string'
                and type(payload.os) == 'string'
                and type(payload.arch) == 'string'
                and type(payload.current_dir) == 'string'
                and type(payload.main_separator) == 'string'
                and type(payload.username) == 'string'
                and type(payload.shell) == 'string'
            )
        end,
        timeout = opts.timeout,
        interval = opts.interval,
    }, cb)
end

--- @alias distant.core.api.WriteFileOpts {path:string, data:integer[], timeout?:number, interval?:number}
--- @param opts distant.core.api.WriteFileOpts
--- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.OkPayload)
--- @return distant.core.api.Error|nil,distant.core.api.OkPayload|nil
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
        verify = verify_ok,
        timeout = opts.timeout,
        interval = opts.interval,
    }, cb)
end

--- @alias distant.core.api.WriteFileTextOpts {path:string, text:string, timeout?:number, interval?:number}
--- @param opts distant.core.api.WriteFileTextOpts
--- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.OkPayload)
--- @return distant.core.api.Error|nil,distant.core.api.OkPayload|nil
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
        verify = verify_ok,
        timeout = opts.timeout,
        interval = opts.interval,
    }, cb)
end

--- @alias distant.core.api.watch.ChangeKind
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

--- @class distant.core.api.WatchOpts
--- @field path string
--- @field recursive? boolean
--- @field only? distant.core.api.watch.ChangeKind[]
--- @field except? distant.core.api.watch.ChangeKind[]
--- @field timeout? number
--- @field interval? number

--- @class distant.core.api.WatchPayload
--- @field type 'changed'
--- @field kind distant.core.api.watch.ChangeKind
--- @field paths string[]

--- Begins watching a path for changes.
---
--- NOTE: This function does NOT have a synchronous equivalent!
---
--- @param opts distant.core.api.WatchOpts
--- @param cb fun(err?:distant.core.api.Error, payload?:distant.core.api.WatchPayload)
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
        verify = verify_ok,
        more = function(payload)
            -- TODO: We need some way to cleanup the callback when
            --       the path has been unwatched!
            return payload.type == 'changed' or payload.type == 'ok'
        end,
        timeout = opts.timeout,
        interval = opts.interval,
    }, function(err, payload)
        -- NOTE: It's possible to get a payload of "ok" when
        --       as it is sent in response to the initial
        --       watch request. We want to skip that payload!
        if err then
            cb(err, nil)
        elseif payload.type == 'changed' then
            cb(nil, payload)
        end
    end)
end

--- @alias distant.core.api.UnwatchOpts {path:string, timeout?:number, interval?:number}
--- @param opts distant.core.api.UnwatchOpts
--- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.OkPayload)
--- @return distant.core.api.Error|nil,distant.core.api.OkPayload|nil
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
        verify = verify_ok,
        timeout = opts.timeout,
        interval = opts.interval,
    }, cb)
end

return M
