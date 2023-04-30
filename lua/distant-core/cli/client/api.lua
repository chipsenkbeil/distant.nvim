local Transport = require('distant-core.cli.client.transport')
local log = require('distant-core.log')

--- @class DistantApiError
--- @field kind DistantApiErrorKind
--- @field description string

--- @enum DistantApiErrorKind
local ERROR_KIND = {
    NotFound          = 'not_found',
    PermissionDenied  = 'permission_denied',
    ConnectionRefused = 'connection_refused',
    ConnectionReset   = 'connection_reset',
    ConnectionAborted = 'connection_aborted',
    NotConnected      = 'not_connected',
    AddrInUse         = 'addr_in_use',
    AddrNotAvailable  = 'addr_not_available',
    BrokenPipe        = 'broken_pipe',
    AlreadyExists     = 'already_exists',
    WouldBlock        = 'would_block',
    InvalidInput      = 'invalid_input',
    InvalidData       = 'invalid_data',
    TimedOut          = 'timed_out',
    WriteZero         = 'write_zero',
    Interrupted       = 'interrupted',
    Other             = 'other',
    UnexpectedEof     = 'unexpected_eof',
    Unsupported       = 'unsupported',
    OutOfMemory       = 'out_of_memory',
    Loop              = 'loop',
    TaskCancelled     = 'task_cancelled',
    TaskPanicked      = 'task_panicked',
    Unknown           = 'unknown',
}

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
    return self:__send({
        payload = {
            type = 'append_file',
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
    return self:__send({
        payload = {
            type = 'append_file_text',
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
    return self:__send({
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
    return self:__send({
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
    return self:__send({
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
    return self:__send({
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
    return self:__send({
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
    return self:__send({
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
    return self:__send({
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
    return self:__send({
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
    return self:__send({
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
    return self:__send({
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

--- @class DistantApiSendOpts
--- @field payload table
--- @field cb? fun(err?:string, payload?:table)
--- @field verify fun(payload:table):boolean
--- @field map? fun(payload:table):any
--- @field timeout? number
--- @field interval? number

--- @param opts DistantApiSendOpts
function M:__send(opts)
    local payload = opts.payload
    local cb = opts.cb

    -- Asynchronous if cb provided, otherwise synchronous
    if type(cb) == 'function' then
        self.transport:send({ payload = payload }, function(res)
            if type(res) == 'table' and res.type == 'error' then
                if type(res.description) == 'string' then
                    cb(res.description, nil)
                else
                    cb('Malformed error received: ' .. vim.inspect(res), nil)
                end

                return
            end

            --- @diagnostic disable-next-line:param-type-mismatch
            if not type(res) == 'table' or not opts.verify(res) then
                cb('Invalid response payload: ' .. vim.inspect(res), nil)
                return
            end

            if type(opts.map) == 'function' and type(res) == 'table' then
                res = opts.map(res)
            end

            cb(nil, res)
        end)
    else
        local err, res = self.transport:send_wait({
            payload = payload,
            timeout = opts.timeout,
            interval = opts.interval
        })

        if err then
            return err
        end

        if type(res) == 'table' and res.type == 'error' then
            if type(res.description) == 'string' then
                return res.description
            else
                return 'Malformed error received: ' .. vim.inspect(res)
            end
        end

        --- @diagnostic disable-next-line:param-type-mismatch
        if not type(res) == 'table' or not opts.verify(res) then
            return 'Invalid response payload: ' .. vim.inspect(res)
        end

        if type(opts.map) == 'function' and type(res) == 'table' then
            res = opts.map(res)
        end

        return nil, res
    end
end

return M
