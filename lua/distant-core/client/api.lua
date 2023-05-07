local Error = require('distant-core.client.api.error')
local Process = require('distant-core.client.api.process')
local Searcher = require('distant-core.client.api.searcher')
local Transport = require('distant-core.client.transport')
local log = require('distant-core.log')

--- Represents an API that uses a transport to communicate payloads.
--- @class distant.client.Api
--- @field private transport distant.api.Transport
local M = {}
M.__index = M

--- @param opts {binary:string, network?:distant.client.Network, auth_handler?:distant.core.auth.Handler, timeout?:number, interval?:number}
--- @return distant.client.Api
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

--- @alias distant.api.OkPayload {type:'ok'}
local function verify_ok(payload)
    return type(payload) == 'table' and payload.type == 'ok'
end

--- @alias distant.api.AppendFileOpts {path:string, data:integer[], timeout?:number, interval?:number}
--- @param opts distant.api.AppendFileOpts
--- @param cb? fun(err?:distant.api.Error, payload?:distant.api.OkPayload)
--- @return distant.api.Error|nil,distant.api.OkPayload|nil
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

--- @alias distant.api.AppendFileTextOpts {path:string, text:string, timeout?:number, interval?:number}
--- @param opts distant.api.AppendFileTextOpts
--- @param cb? fun(err?:distant.api.Error, payload?:distant.api.OkPayload)
--- @return distant.api.Error|nil,distant.api.OkPayload|nil
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

--- @alias distant.api.CapabilitiesOpts {timeout?:number, interval?:number}
--- @alias distant.api.CapabilitiesPayload {type:'capabilities', supported:string[]}
--- @param opts distant.api.CapabilitiesOpts
--- @param cb? fun(err?:distant.api.Error, payload?:distant.api.CapabilitiesPayload)
--- @return distant.api.Error|nil,distant.api.CapabilitiesPayload|nil
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

--- @alias distant.api.CopyOpts {src:string, dst:string, timeout?:number, interval?:number}
--- @param opts distant.api.CopyOpts
--- @param cb? fun(err?:distant.api.Error, payload?:distant.api.OkPayload)
--- @return distant.api.Error|nil,distant.api.OkPayload|nil
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

--- @alias distant.api.CreateDirOpts {path:string, all?:boolean, timeout?:number, interval?:number}
--- @param opts distant.api.CreateDirOpts
--- @param cb? fun(err?:distant.api.Error, payload?:distant.api.OkPayload)
--- @return distant.api.Error|nil,distant.api.OkPayload|nil
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

--- @alias distant.api.ExistsOpts {path:string, timeout?:number, interval?:number}
--- @param opts distant.api.ExistsOpts
--- @param cb? fun(err?:distant.api.Error, payload?:boolean)
--- @return distant.api.Error|nil,boolean|nil
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
        cb = cb,
        verify = function(payload)
            return payload.type == 'exists'
        end,
        map = function(payload) return payload.value end,
        timeout = opts.timeout,
        interval = opts.interval,
    })

    --- @cast value -table, +boolean
    return err, value
end

--- @class distant.api.MetadataPayload
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

--- @class distant.api.MetadataOpts
--- @field path string
--- @field canonicalize? boolean
--- @field resolve_file_type? boolean
--- @field timeout? number
--- @field interval? number

--- @param opts distant.api.MetadataOpts
--- @param cb? fun(err?:distant.api.Error, payload?:distant.api.MetadataPayload)
--- @return distant.api.Error|nil,distant.api.MetadataPayload|nil
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

--- @class distant.api.DirEntry
--- @field path string
--- @field file_type 'dir'|'file'|'symlink'
--- @field depth number

--- @class distant.api.ReadDirOpts
--- @field path string
--- @field depth? number
--- @field absolute? boolean
--- @field canonicalize? boolean
--- @field include_root? boolean
--- @field timeout? number
--- @field interval? number

--- @class distant.api.ReadDirPayload
--- @field type 'dir_entries'
--- @field entries distant.api.DirEntry[]
--- @field errors distant.api.Error[]

--- @param opts distant.api.ReadDirOpts
--- @param cb? fun(err?:distant.api.Error, payload?:distant.api.ReadDirPayload)
--- @return distant.api.Error|nil,distant.api.ReadDirPayload|nil
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
        map = function(payload)
            return {
                entries = payload.entries,
                errors = vim.tbl_map(function(e) return Error:new(e) end, payload.errors),
            }
        end,
        timeout = opts.timeout,
        interval = opts.interval,
    })
end

--- @alias distant.api.ReadFileOpts {path:string, timeout?:number, interval?:number}
--- @param opts distant.api.ReadFileOpts
--- @param cb? fun(err?:distant.api.Error, payload?:number[])
--- @return distant.api.Error|nil,number[]|nil
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

--- @alias distant.api.ReadFileTextOpts {path:string, timeout?:number, interval?:number}
--- @param opts distant.api.ReadFileTextOpts
--- @param cb? fun(err?:distant.api.Error, payload?:string)
--- @return distant.api.Error|nil,string|nil
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
        cb = cb,
        verify = function(payload)
            return payload.type == 'text' and type(payload.data) == 'string'
        end,
        map = function(payload) return payload.data end,
        timeout = opts.timeout,
        interval = opts.interval,
    })

    --- @cast value -table, +string
    return err, value
end

--- @alias distant.api.RemoveOpts {path:string, force?:boolean, timeout?:number, interval?:number}
--- @param opts distant.api.RemoveOpts
--- @param cb? fun(err?:distant.api.Error, payload?:distant.api.OkPayload)
--- @return distant.api.Error|nil,distant.api.OkPayload|nil
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

--- @alias distant.api.RenameOpts {src:string, dst:string, timeout?:number, interval?:number}
--- @param opts distant.api.RenameOpts
--- @param cb? fun(err?:distant.api.Error, payload?:distant.api.OkPayload)
--- @return distant.api.Error|nil,distant.api.OkPayload|nil
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

--- @class distant.api.SearchOpts
--- @field query distant.api.search.Query
--- @field on_results? fun(matches:distant.api.search.Match[])
--- @field on_start? fun(id:integer)
--- @field timeout? number
--- @field interval? number

--- @param opts distant.api.SearchOpts
--- @param cb? fun(err?:distant.api.Error, matches?:distant.api.search.Match[])
--- @return distant.api.Error|nil, distant.api.Searcher|distant.api.search.Match[]|nil
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

--- @param opts distant.api.process.SpawnOpts
--- @param cb? fun(err?:distant.api.Error, results?:distant.api.process.SpawnResults)
--- @return distant.api.Error|nil, distant.api.Process|distant.api.process.SpawnResults|nil
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

--- @class distant.api.SystemInfoPayload
--- @field type 'system_info'
--- @field family string
--- @field os string
--- @field arch string
--- @field current_dir string
--- @field main_separator string

--- @alias distant.api.SystemInfoOpts {timeout?:number, interval?:number}
--- @param opts distant.api.SystemInfoOpts
--- @param cb? fun(err?:distant.api.Error, payload?:distant.api.SystemInfoPayload)
--- @return distant.api.Error|nil,distant.api.SystemInfoPayload|nil
function M:system_info(opts, cb)
    vim.validate({
        opts = { opts, 'table' },
        cb = { cb, 'function', true },
    })

    return self.transport:send({
        payload = {
            type = 'system_info',
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

--- @alias distant.api.WriteFileOpts {path:string, data:integer[], timeout?:number, interval?:number}
--- @param opts distant.api.WriteFileOpts
--- @param cb? fun(err?:distant.api.Error, payload?:distant.api.OkPayload)
--- @return distant.api.Error|nil,distant.api.OkPayload|nil
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

--- @alias distant.api.WriteFileTextOpts {path:string, text:string, timeout?:number, interval?:number}
--- @param opts distant.api.WriteFileTextOpts
--- @param cb? fun(err?:distant.api.Error, payload?:distant.api.OkPayload)
--- @return distant.api.Error|nil,distant.api.OkPayload|nil
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

--- @alias distant.api.watch.ChangeKind
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

--- @class distant.api.WatchOpts
--- @field path string
--- @field recursive? boolean
--- @field only? distant.api.watch.ChangeKind[]
--- @field except? distant.api.watch.ChangeKind[]
--- @field timeout? number
--- @field interval? number

--- @class distant.api.WatchPayload
--- @field type 'changed'
--- @field kind distant.api.watch.ChangeKind
--- @field paths string[]

--- Begins watching a path for changes.
---
--- NOTE: This function does NOT have a synchronous equivalent!
---
--- @param opts distant.api.WatchOpts
--- @param cb fun(err?:distant.api.Error, payload?:distant.api.WatchPayload)
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
        cb = function(err, payload)
            -- NOTE: It's possible to get a payload of "ok" when
            --       as it is sent in response to the initial
            --       watch request. We want to skip that payload!
            if err then
                cb(err, nil)
            elseif payload.type == 'changed' then
                cb(nil, payload)
            end
        end,
        verify = verify_ok,
        more = function(payload)
            -- TODO: We need some way to cleanup the callback when
            --       the path has been unwatched!
            return payload.type == 'changed' or payload.type == 'ok'
        end,
        timeout = opts.timeout,
        interval = opts.interval,
    })
end

--- @alias distant.api.UnwatchOpts {path:string, timeout?:number, interval?:number}
--- @param opts distant.api.UnwatchOpts
--- @param cb? fun(err?:distant.api.Error, payload?:distant.api.OkPayload)
--- @return distant.api.Error|nil,distant.api.OkPayload|nil
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
