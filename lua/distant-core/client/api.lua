local Error = require('distant-core.client.api.error')
local Process = require('distant-core.client.api.process')
local Searcher = require('distant-core.client.api.searcher')
local Transport = require('distant-core.client.transport')
local log = require('distant-core.log')

--- Represents an API that uses a transport to communicate payloads.
--- @class DistantApi
--- @field private transport DistantApiTransport
local M = {}
M.__index = M

--- @param opts {binary:string, network?:DistantClientNetwork, auth_handler?:AuthHandler, timeout?:number, interval?:number}
--- @return DistantApi
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

--- @alias OkPayload {type:'ok'}
local function verify_ok(payload)
    return type(payload) == 'table' and payload.type == 'ok'
end

--- @alias DistantApiAppendFileOpts {path:string, data:integer[], timeout?:number, interval?:number}
--- @param opts DistantApiAppendFileOpts
--- @param cb? fun(err?:DistantApiError, payload?:OkPayload)
--- @return DistantApiError|nil,OkPayload|nil
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

--- @alias DistantApiAppendFileTextOpts {path:string, text:string, timeout?:number, interval?:number}
--- @param opts DistantApiAppendFileTextOpts
--- @param cb? fun(err?:DistantApiError, payload?:OkPayload)
--- @return DistantApiError|nil,OkPayload|nil
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

--- @alias DistantApiCapabilitiesOpts {timeout?:number, interval?:number}
--- @alias DistantApiCapabilitiesPayload {type:'capabilities', supported:string[]}
--- @param opts DistantApiCapabilitiesOpts
--- @param cb? fun(err?:DistantApiError, payload?:DistantApiCapabilitiesPayload)
--- @return DistantApiError|nil,DistantApiCapabilitiesPayload|nil
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

--- @alias DistantApiCopyOpts {src:string, dst:string, timeout?:number, interval?:number}
--- @param opts DistantApiCopyOpts
--- @param cb? fun(err?:DistantApiError, payload?:OkPayload)
--- @return DistantApiError|nil,OkPayload|nil
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

--- @alias DistantApiCreateDirOpts {path:string, all?:boolean, timeout?:number, interval?:number}
--- @param opts DistantApiCreateDirOpts
--- @param cb? fun(err?:DistantApiError, payload?:OkPayload)
--- @return DistantApiError|nil,OkPayload|nil
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

--- @alias DistantApiExistsOpts {path:string, timeout?:number, interval?:number}
--- @param opts DistantApiExistsOpts
--- @param cb? fun(err?:DistantApiError, payload?:boolean)
--- @return DistantApiError|nil,boolean|nil
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
        verify = verify_ok,
        map = function(payload) return payload.value end,
        timeout = opts.timeout,
        interval = opts.interval,
    })

    --- @cast value -table, +boolean
    return err, value
end

--- @class DistantApiMetadataPayload
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

--- @alias DistantApiMetadataOpts {path:string, canonicalize?:boolean, resolve_file_type?:boolean, timeout?:number, interval?:number}
--- @param opts DistantApiMetadataOpts
--- @param cb? fun(err?:DistantApiError, payload?:DistantApiMetadataPayload)
--- @return DistantApiError|nil,DistantApiMetadataPayload|nil
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

--- @alias DistantApiReadDirOpts {path:string, depth?:number, absolute?:boolean, canonicalize?:boolean, include_root?:boolean, timeout?:number, interval?:number}
--- @alias DistantApiReadDirPayload {type:'dir_entries', entries:DistantDirEntry[], errors:DistantApiError[]}
--- @param opts DistantApiReadDirOpts
--- @param cb? fun(err?:DistantApiError, payload?:DistantApiReadDirPayload)
--- @return DistantApiError|nil,DistantApiReadDirPayload|nil
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

--- @alias DistantApiReadFileOpts {path:string, timeout?:number, interval?:number}
--- @param opts DistantApiReadFileOpts
--- @param cb? fun(err?:DistantApiError, payload?:number[])
--- @return DistantApiError|nil,number[]|nil
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

--- @alias DistantApiReadFileTextOpts {path:string, timeout?:number, interval?:number}
--- @param opts DistantApiReadFileTextOpts
--- @param cb? fun(err?:DistantApiError, payload?:string)
--- @return DistantApiError|nil,string|nil
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

--- @alias DistantApiRemoveOpts {path:string, force?:boolean, timeout?:number, interval?:number}
--- @param opts DistantApiRemoveOpts
--- @param cb? fun(err?:DistantApiError, payload?:OkPayload)
--- @return DistantApiError|nil,OkPayload|nil
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

--- @alias DistantApiRenameOpts {src:string, dst:string, timeout?:number, interval?:number}
--- @param opts DistantApiRenameOpts
--- @param cb? fun(err?:DistantApiError, payload?:OkPayload)
--- @return DistantApiError|nil,OkPayload|nil
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

--- @class DistantApiSearchOpts
--- @field query DistantApiSearchQuery
--- @field on_results? fun(matches:DistantApiSearchMatch[])
--- @field on_start? fun(id:integer)
--- @field timeout? number
--- @field interval? number

--- @param opts DistantApiSearchOpts
--- @param cb? fun(err?:DistantApiError, matches?:DistantApiSearchMatch[])
--- @return DistantApiError|nil, DistantApiSearcher|DistantApiSearchMatch[]|nil
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

--- @param opts DistantApiProcessSpawnOpts
--- @param cb? fun(err?:DistantApiError, results?:DistantApiProcessSpawnResults)
--- @return DistantApiError|nil, DistantApiProcess|DistantApiProcessSpawnResults|nil
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

--- @class DistantApiSystemInfoPayload
--- @field type 'system_info'
--- @field family string
--- @field os string
--- @field arch string
--- @field current_dir string
--- @field main_separator string

--- @alias DistantApiSystemInfoOpts {timeout?:number, interval?:number}
--- @param opts DistantApiSystemInfoOpts
--- @param cb? fun(err?:DistantApiError, payload?:DistantApiSystemInfoPayload)
--- @return DistantApiError|nil,DistantApiSystemInfoPayload|nil
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

--- @alias DistantApiWriteFileOpts {path:string, data:integer[], timeout?:number, interval?:number}
--- @param opts DistantApiWriteFileOpts
--- @param cb? fun(err?:DistantApiError, payload?:OkPayload)
--- @return DistantApiError|nil,OkPayload|nil
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

--- @alias DistantApiWriteFileTextOpts {path:string, text:string, timeout?:number, interval?:number}
--- @param opts DistantApiWriteFileTextOpts
--- @param cb? fun(err?:DistantApiError, payload?:OkPayload)
--- @return DistantApiError|nil,OkPayload|nil
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
--- @alias DistantApiWatchOpts {path:string, recursive?:boolean, only?:ChangeKind[], except?:ChangeKind[], timeout?:number, interval?:number}
--- @alias DistantApiWatchPayload {type:'changed', kind:ChangeKind, paths:string[]}
--- @param opts DistantApiWatchOpts
--- @param cb fun(err?:DistantApiError, payload?:DistantApiWatchPayload)
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

--- @alias DistantApiUnwatchOpts {path:string, timeout?:number, interval?:number}
--- @param opts DistantApiUnwatchOpts
--- @param cb? fun(err?:DistantApiError, payload?:OkPayload)
--- @return DistantApiError|nil,OkPayload|nil
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
