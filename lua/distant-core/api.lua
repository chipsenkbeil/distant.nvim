local Error = require('distant-core.api.error')
local Process = require('distant-core.api.process')
local Searcher = require('distant-core.api.searcher')
local Transport = require('distant-core.api.transport')

local log = require('distant-core.log')

-------------------------------------------------------------------------------
-- CLASS DEFINITION & CREATION
-------------------------------------------------------------------------------

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

-------------------------------------------------------------------------------
-- GENERAL API
-------------------------------------------------------------------------------

function M:start()
    self.transport:start(function(exit_code)
        log.fmt_debug('API process exited: %s', exit_code)
    end)
end

function M:stop()
    self.transport:stop()
end

-------------------------------------------------------------------------------
-- REQUEST DEFINITIONS
-------------------------------------------------------------------------------

--- @enum distant.core.api.RequestType
local REQUEST_TYPE = {
    CAPABILITIES     = 'capabilities',
    CANCEL_SEARCH    = 'cancel_search',
    COPY             = 'copy',
    DIR_CREATE       = 'dir_create',
    DIR_READ         = 'dir_read',
    EXISTS           = 'exists',
    FILE_APPEND      = 'file_append',
    FILE_APPEND_TEXT = 'file_append_text',
    FILE_READ        = 'file_read',
    FILE_READ_TEXT   = 'file_read_text',
    FILE_WRITE       = 'file_write',
    FILE_WRITE_TEXT  = 'file_write_text',
    METADATA         = 'metadata',
    PROC_KILL        = 'proc_kill',
    PROC_RESIZE_PTY  = 'proc_resize_pty',
    PROC_SPAWN       = 'proc_spawn',
    PROC_STDIN       = 'proc_stdin',
    REMOVE           = 'remove',
    RENAME           = 'rename',
    SEARCH           = 'search',
    SYSTEM_INFO      = 'system_info',
    UNWATCH          = 'unwatch',
    WATCH            = 'watch',
}

-------------------------------------------------------------------------------
-- REQUEST HANDLERS
-------------------------------------------------------------------------------

--- @generic T
--- @param x T
--- @return T
local function identity(x)
    return x
end

--- @alias distant.core.api.OkPayload {type:'ok'}
--- @param payload distant.core.api.OkPayload
local function verify_ok(payload)
    return type(payload) == 'table' and payload.type == 'ok'
end

--- @param payload table
--- @return string[]
local function map_capabilities(payload)
    return payload.supported
end

--- @param payload table
--- @return boolean
local function verify_capabilities(payload)
    return (
        payload.type == 'capabilities'
        and type(payload.supported) == 'table'
        and vim.tbl_islist(payload.supported)
        )
end

--- @param payload table
local function map_dir_read(payload)
    return {
        entries = payload.entries,
        errors = vim.tbl_map(function(e) return Error:new(e) end, payload.errors),
    }
end

--- @param payload table
--- @return boolean
local function verify_dir_read(payload)
    return payload.type == 'dir_entries' and vim.tbl_islist(payload.entries) and vim.tbl_islist(payload.errors)
end

--- @param payload table
--- @return boolean
local function map_exists(payload)
    return payload.value
end

--- @param payload table
--- @return boolean
local function verify_exists(payload)
    return payload.type == 'exists'
end

--- @param payload table
--- @return integer[]
local function map_file_read(payload)
    return payload.data
end

--- @param payload table
--- @return boolean
local function verify_file_read(payload)
    return payload.type == 'blob' and vim.tbl_islist(payload.data)
end

--- @param payload table
--- @return string
local function map_file_read_text(payload)
    return payload.data
end

--- @param payload table
--- @return boolean
local function verify_file_read_text(payload)
    return payload.type == 'text' and type(payload.data) == 'string'
end

--- @param payload table
--- @return boolean
local function verify_metadata(payload)
    return (
        payload.type == 'metadata'
        and type(payload.file_type) == 'string'
        and type(payload.len) == 'number'
        and type(payload.readonly) == 'boolean')
end

--- @param payload table
--- @return boolean
local function verify_system_info(payload)
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
end

--- Mapping of request types to handlers to verify and map responses.
--- @alias distant.core.api.RequestHandlers { map:(fun(payload:table):any), verify:(fun(payload:table):boolean) }
--- @type { [distant.core.api.RequestType]: distant.core.api.RequestHandlers }
local RESPONSE_HANDLERS = {
    [REQUEST_TYPE.CAPABILITIES]     = { map = map_capabilities, verify = verify_capabilities },
    [REQUEST_TYPE.CANCEL_SEARCH]    = { map = identity, verify = verify_ok },
    [REQUEST_TYPE.COPY]             = { map = identity, verify = verify_ok },
    [REQUEST_TYPE.DIR_CREATE]       = { map = identity, verify = verify_ok },
    [REQUEST_TYPE.DIR_READ]         = { map = map_dir_read, verify = verify_dir_read },
    [REQUEST_TYPE.EXISTS]           = { map = map_exists, verify = verify_exists },
    [REQUEST_TYPE.FILE_APPEND]      = { map = identity, verify = verify_ok },
    [REQUEST_TYPE.FILE_APPEND_TEXT] = { map = identity, verify = verify_ok },
    [REQUEST_TYPE.FILE_READ]        = { map = map_file_read, verify = verify_file_read },
    [REQUEST_TYPE.FILE_READ_TEXT]   = { map = map_file_read_text, verify = verify_file_read_text },
    [REQUEST_TYPE.FILE_WRITE]       = { map = identity, verify = verify_ok },
    [REQUEST_TYPE.FILE_WRITE_TEXT]  = { map = identity, verify = verify_ok },
    [REQUEST_TYPE.METADATA]         = { map = identity, verify = verify_metadata },
    [REQUEST_TYPE.PROC_KILL]        = { map = identity, verify = verify_ok },
    [REQUEST_TYPE.PROC_RESIZE_PTY]  = { map = identity, verify = verify_ok },
    [REQUEST_TYPE.PROC_SPAWN]       = { map = identity, verify = verify_ok },
    [REQUEST_TYPE.PROC_STDIN]       = { map = identity, verify = verify_ok },
    [REQUEST_TYPE.REMOVE]           = { map = identity, verify = verify_ok },
    [REQUEST_TYPE.RENAME]           = { map = identity, verify = verify_ok },
    [REQUEST_TYPE.SEARCH]           = { map = identity, verify = verify_ok },
    [REQUEST_TYPE.SYSTEM_INFO]      = { map = identity, verify = verify_system_info },
    [REQUEST_TYPE.UNWATCH]          = { map = identity, verify = verify_ok },
    [REQUEST_TYPE.WATCH]            = { map = identity, verify = verify_ok },
}

-------------------------------------------------------------------------------
-- BATCH API
-------------------------------------------------------------------------------

--- Sends a series of API requests together as a single batch.
---
--- * `opts` - list of requests to send as well as specific options that can be passed.
--- * `opts.timeout` - maximum time to wait for a synchronous response.
--- * `opts.interval` -
---
--- # Synchronous Example
---
--- ```lua
--- local err, results = api.batch({
---     { type = 'exists', path = '/path/to/file1.txt },
---     { type = 'exists', path = '/path/to/file2.txt },
---     { type = 'metadata', path = '/path/to/file3.txt },
---     { type = 'system_info' },
--- })
---
--- -- Verify we did not get an error
--- assert(not err, tostring(err))
---
--- -- { payload = true }
--- print(vim.inspect(results[1]))
---
--- -- { payload = value = false }
--- print(vim.inspect(results[2]))
---
--- -- { err = distant.api.Error { .. } }
--- print(vim.inspect(results[3]))
---
--- -- { payload = { family = 'unix', .. } }
--- print(vim.inspect(results[4]))
--- ```
---
--- # Asynchronous Example
---
--- ```lua
--- api.batch({
---     { type = 'exists', path = '/path/to/file1.txt },
---     { type = 'exists', path = '/path/to/file2.txt },
---     { type = 'metadata', path = '/path/to/file3.txt },
---     { type = 'system_info' },
--- }, function(err, results)
---     assert(not err, tostring(err))
---
---     -- { payload = true }
---     print(vim.inspect(results[1]))
---
---     -- { payload = value = false }
---     print(vim.inspect(results[2]))
---
---     -- { err = distant.api.Error { .. } }
---     print(vim.inspect(results[3]))
---
---     -- { payload = { family = 'unix', .. } }
---     print(vim.inspect(results[4]))
--- end)
--- ```
---
--- @generic T: table
--- @param opts {[number]: table, timeout?:number, interval?:number}
--- @param cb? fun(err?:distant.core.api.Error, payload?:{err?:distant.core.api.Error, payload?:table}[])
--- @return distant.core.api.Error|nil err, {err?:distant.core.api.Error, payload?:table}[]|nil payload
function M:batch(opts, cb)
    vim.validate({
        opts = { opts, 'table' },
        cb = { cb, 'function', true },
    })

    local timeout = opts.timeout
    opts.timeout = nil

    local interval = opts.interval
    opts.interval = nil

    -- Validate the payload by checking it contains types
    assert(vim.tbl_islist(opts), 'Batch not provided a list of payloads')
    --- @type distant.core.api.RequestHandlers[]
    local handlers = {}
    for idx, payload in ipairs(opts) do
        assert(type(payload.type) == 'string', ('[%s] Invalid type field'):format(idx))
        local h = assert(
            RESPONSE_HANDLERS[payload.type],
            ('[%s] Missing handlers for %s'):format(idx, payload.type)
        )
        table.insert(handlers, h)
    end

    return self.transport:send({
        payload = opts,
        verify = function(payload)
            return type(payload) == 'table' and vim.tbl_islist(payload)
        end,
        map = function(payload)
            -- Map errors versus regular responses
            for idx, data in ipairs(payload) do
                local h = handlers[idx]
                if data.type == 'error' then
                    payload[idx] = { err = Error:new(data) }
                elseif h then
                    if h.verify(data) then
                        payload[idx] = { payload = h.map(data) }
                    else
                        payload[idx] = {
                            err = Error:new({
                                kind = Error.kinds.invalid_data,
                                description = 'Invalid response payload: ' .. vim.inspect(data),
                            })
                        }
                    end
                else
                    payload[idx] = { payload = data }
                end
            end

            return payload
        end,
        timeout = timeout,
        interval = interval,
    }, cb)
end

-------------------------------------------------------------------------------
-- REQUEST API
-------------------------------------------------------------------------------

--- @alias distant.core.api.AppendFileOpts {path:string, data:integer[], timeout?:number, interval?:number}
--- @param opts distant.core.api.AppendFileOpts
--- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.OkPayload)
--- @return distant.core.api.Error|nil err, distant.core.api.OkPayload|nil payload
function M:append_file(opts, cb)
    vim.validate({
        opts = { opts, 'table' },
        cb = { cb, 'function', true },
    })

    local ty = REQUEST_TYPE.FILE_APPEND
    local handlers = assert(RESPONSE_HANDLERS[ty], 'Missing handlers for ' .. ty)

    return self.transport:send({
        payload = {
            type = ty,
            path = opts.path,
            data = opts.data,
        },
        map = handlers.map,
        verify = handlers.verify,
        timeout = opts.timeout,
        interval = opts.interval,
    }, cb)
end

--- @alias distant.core.api.AppendFileTextOpts {path:string, text:string, timeout?:number, interval?:number}
--- @param opts distant.core.api.AppendFileTextOpts
--- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.OkPayload)
--- @return distant.core.api.Error|nil err, distant.core.api.OkPayload|nil payload
function M:append_file_text(opts, cb)
    vim.validate({
        opts = { opts, 'table' },
        cb = { cb, 'function', true },
    })

    local ty = REQUEST_TYPE.FILE_APPEND_TEXT
    local handlers = assert(RESPONSE_HANDLERS[ty], 'Missing handlers for ' .. ty)

    return self.transport:send({
        payload = {
            type = ty,
            path = opts.path,
            text = opts.text,
        },
        map = handlers.map,
        verify = handlers.verify,
        timeout = opts.timeout,
        interval = opts.interval,
    }, cb)
end

--- @alias distant.core.api.CapabilitiesOpts {timeout?:number, interval?:number}
--- @param opts distant.core.api.CapabilitiesOpts
--- @param cb? fun(err?:distant.core.api.Error, payload?:string[])
--- @return distant.core.api.Error|nil err, string[]|nil capabilities
function M:capabilities(opts, cb)
    vim.validate({
        opts = { opts, 'table' },
        cb = { cb, 'function', true },
    })

    local ty = REQUEST_TYPE.CAPABILITIES
    local handlers = assert(RESPONSE_HANDLERS[ty], 'Missing handlers for ' .. ty)

    return self.transport:send({
        payload = {
            type = ty,
        },
        map = handlers.map,
        verify = handlers.verify,
        timeout = opts.timeout,
        interval = opts.interval,
    }, cb)
end

--- @alias distant.core.api.CopyOpts {src:string, dst:string, timeout?:number, interval?:number}
--- @param opts distant.core.api.CopyOpts
--- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.OkPayload)
--- @return distant.core.api.Error|nil err, distant.core.api.OkPayload|nil payload
function M:copy(opts, cb)
    vim.validate({
        opts = { opts, 'table' },
        cb = { cb, 'function', true },
    })

    local ty = REQUEST_TYPE.COPY
    local handlers = assert(RESPONSE_HANDLERS[ty], 'Missing handlers for ' .. ty)

    return self.transport:send({
        payload = {
            type = ty,
            src = opts.src,
            dst = opts.dst,
        },
        map = handlers.map,
        verify = handlers.verify,
        timeout = opts.timeout,
        interval = opts.interval,
    }, cb)
end

--- @alias distant.core.api.CreateDirOpts {path:string, all?:boolean, timeout?:number, interval?:number}
--- @param opts distant.core.api.CreateDirOpts
--- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.OkPayload)
--- @return distant.core.api.Error|nil err, distant.core.api.OkPayload|nil payload
function M:create_dir(opts, cb)
    vim.validate({
        opts = { opts, 'table' },
        cb = { cb, 'function', true },
    })

    local ty = REQUEST_TYPE.DIR_CREATE
    local handlers = assert(RESPONSE_HANDLERS[ty], 'Missing handlers for ' .. ty)

    return self.transport:send({
        payload = {
            type = ty,
            path = opts.path,
            all = opts.all,
        },
        map = handlers.map,
        verify = handlers.verify,
        timeout = opts.timeout,
        interval = opts.interval,
    }, cb)
end

--- @alias distant.core.api.ExistsOpts {path:string, timeout?:number, interval?:number}
--- @param opts distant.core.api.ExistsOpts
--- @param cb? fun(err?:distant.core.api.Error, payload?:boolean)
--- @return distant.core.api.Error|nil err, boolean|nil exists
function M:exists(opts, cb)
    vim.validate({
        opts = { opts, 'table' },
        cb = { cb, 'function', true },
    })

    local ty = REQUEST_TYPE.EXISTS
    local handlers = assert(RESPONSE_HANDLERS[ty], 'Missing handlers for ' .. ty)

    local err, value = self.transport:send({
        payload = {
            type = ty,
            path = opts.path,
        },
        map = handlers.map,
        verify = handlers.verify,
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
--- @return distant.core.api.Error|nil err, distant.core.api.MetadataPayload|nil metadata
function M:metadata(opts, cb)
    vim.validate({
        opts = { opts, 'table' },
        cb = { cb, 'function', true },
    })

    local ty = REQUEST_TYPE.METADATA
    local handlers = assert(RESPONSE_HANDLERS[ty], 'Missing handlers for ' .. ty)

    return self.transport:send({
        payload = {
            type = ty,
            path = opts.path,
            canonicalize = opts.canonicalize,
            resolve_file_type = opts.resolve_file_type,
        },
        map = handlers.map,
        verify = handlers.verify,
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
--- @return distant.core.api.Error|nil err, distant.core.api.ReadDirPayload|nil payload
function M:read_dir(opts, cb)
    vim.validate({
        opts = { opts, 'table' },
        cb = { cb, 'function', true },
    })

    local ty = REQUEST_TYPE.DIR_READ
    local handlers = assert(RESPONSE_HANDLERS[ty], 'Missing handlers for ' .. ty)

    return self.transport:send({
        payload = {
            type = ty,
            path = opts.path,
            depth = opts.depth,
            absolute = opts.absolute,
            canonicalize = opts.canonicalize,
            include_root = opts.include_root,
        },
        map = handlers.map,
        verify = handlers.verify,
        timeout = opts.timeout,
        interval = opts.interval,
    }, cb)
end

--- @alias distant.core.api.ReadFileOpts {path:string, timeout?:number, interval?:number}
--- @param opts distant.core.api.ReadFileOpts
--- @param cb? fun(err?:distant.core.api.Error, payload?:number[])
--- @return distant.core.api.Error|nil err, number[]|nil bytes
function M:read_file(opts, cb)
    vim.validate({
        opts = { opts, 'table' },
        cb = { cb, 'function', true },
    })

    local ty = REQUEST_TYPE.FILE_READ
    local handlers = assert(RESPONSE_HANDLERS[ty], 'Missing handlers for ' .. ty)

    return self.transport:send({
        payload = {
            type = ty,
            path = opts.path,
        },
        map = handlers.map,
        verify = handlers.verify,
        timeout = opts.timeout,
        interval = opts.interval,
    }, cb)
end

--- @alias distant.core.api.ReadFileTextOpts {path:string, timeout?:number, interval?:number}
--- @param opts distant.core.api.ReadFileTextOpts
--- @param cb? fun(err?:distant.core.api.Error, payload?:string)
--- @return distant.core.api.Error|nil err, string|nil text
function M:read_file_text(opts, cb)
    vim.validate({
        opts = { opts, 'table' },
        cb = { cb, 'function', true },
    })

    local ty = REQUEST_TYPE.FILE_READ_TEXT
    local handlers = assert(RESPONSE_HANDLERS[ty], 'Missing handlers for ' .. ty)

    local err, value = self.transport:send({
        payload = {
            type = ty,
            path = opts.path,
        },
        map = handlers.map,
        verify = handlers.verify,
        timeout = opts.timeout,
        interval = opts.interval,
    }, cb)

    --- @cast value -table, +string
    return err, value
end

--- @alias distant.core.api.RemoveOpts {path:string, force?:boolean, timeout?:number, interval?:number}
--- @param opts distant.core.api.RemoveOpts
--- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.OkPayload)
--- @return distant.core.api.Error|nil err, distant.core.api.OkPayload|nil payload
function M:remove(opts, cb)
    vim.validate({
        opts = { opts, 'table' },
        cb = { cb, 'function', true },
    })

    local ty = REQUEST_TYPE.REMOVE
    local handlers = assert(RESPONSE_HANDLERS[ty], 'Missing handlers for ' .. ty)

    return self.transport:send({
        payload = {
            type = ty,
            path = opts.path,
            force = opts.force,
        },
        map = handlers.map,
        verify = handlers.verify,
        timeout = opts.timeout,
        interval = opts.interval,
    }, cb)
end

--- @alias distant.core.api.RenameOpts {src:string, dst:string, timeout?:number, interval?:number}
--- @param opts distant.core.api.RenameOpts
--- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.OkPayload)
--- @return distant.core.api.Error|nil err, distant.core.api.OkPayload|nil payload
function M:rename(opts, cb)
    vim.validate({
        opts = { opts, 'table' },
        cb = { cb, 'function', true },
    })

    local ty = REQUEST_TYPE.RENAME
    local handlers = assert(RESPONSE_HANDLERS[ty], 'Missing handlers for ' .. ty)

    return self.transport:send({
        payload = {
            type = ty,
            src = opts.src,
            dst = opts.dst,
        },
        map = handlers.map,
        verify = handlers.verify,
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
--- @return distant.core.api.Error|nil err, distant.core.api.Searcher|distant.core.api.search.Match[]|nil searcher_or_matches
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
--- @return distant.core.api.Error|nil err, distant.core.api.Process|distant.core.api.process.SpawnResults|nil process_or_results
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
--- @return distant.core.api.Error|nil err, distant.core.api.SystemInfoPayload|nil system_info
function M:system_info(opts, cb)
    vim.validate({
        opts = { opts, 'table' },
        cb = { cb, 'function', true },
    })

    local ty = REQUEST_TYPE.SYSTEM_INFO
    local handlers = assert(RESPONSE_HANDLERS[ty], 'Missing handlers for ' .. ty)

    return self.transport:send({
        payload = {
            type = ty,
        },
        map = handlers.map,
        verify = handlers.verify,
        timeout = opts.timeout,
        interval = opts.interval,
    }, cb)
end

--- @alias distant.core.api.WriteFileOpts {path:string, data:integer[], timeout?:number, interval?:number}
--- @param opts distant.core.api.WriteFileOpts
--- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.OkPayload)
--- @return distant.core.api.Error|nil err, distant.core.api.OkPayload|nil payload
function M:write_file(opts, cb)
    vim.validate({
        opts = { opts, 'table' },
        cb = { cb, 'function', true },
    })

    local ty = REQUEST_TYPE.FILE_WRITE
    local handlers = assert(RESPONSE_HANDLERS[ty], 'Missing handlers for ' .. ty)

    return self.transport:send({
        payload = {
            type = ty,
            path = opts.path,
            data = opts.data,
        },
        map = handlers.map,
        verify = handlers.verify,
        timeout = opts.timeout,
        interval = opts.interval,
    }, cb)
end

--- @alias distant.core.api.WriteFileTextOpts {path:string, text:string, timeout?:number, interval?:number}
--- @param opts distant.core.api.WriteFileTextOpts
--- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.OkPayload)
--- @return distant.core.api.Error|nil err, distant.core.api.OkPayload|nil payload
function M:write_file_text(opts, cb)
    vim.validate({
        opts = { opts, 'table' },
        cb = { cb, 'function', true },
    })

    local ty = REQUEST_TYPE.FILE_WRITE_TEXT
    local handlers = assert(RESPONSE_HANDLERS[ty], 'Missing handlers for ' .. ty)

    return self.transport:send({
        payload = {
            type = ty,
            path = opts.path,
            text = opts.text,
        },
        map = handlers.map,
        verify = handlers.verify,
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

    local ty = REQUEST_TYPE.WATCH
    local handlers = assert(RESPONSE_HANDLERS[ty], 'Missing handlers for ' .. ty)

    return self.transport:send({
        payload = {
            type = ty,
            path = opts.path,
            recursive = opts.recursive,
            only = opts.only,
            except = opts.except,
        },
        map = handlers.map,
        verify = handlers.verify,
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
--- @return distant.core.api.Error|nil err, distant.core.api.OkPayload|nil payload
function M:unwatch(opts, cb)
    vim.validate({
        opts = { opts, 'table' },
        cb = { cb, 'function', true },
    })

    local ty = REQUEST_TYPE.UNWATCH
    local handlers = assert(RESPONSE_HANDLERS[ty], 'Missing handlers for ' .. ty)

    return self.transport:send({
        payload = {
            type = ty,
            path = opts.path,
        },
        map = handlers.map,
        verify = handlers.verify,
        timeout = opts.timeout,
        interval = opts.interval,
    }, cb)
end

return M
