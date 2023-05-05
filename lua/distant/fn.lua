local state = require('distant.state')

--- Retrieves the active client. Throws an error if client not initialized.
--- @return DistantClient
local function client()
    return assert(state.client, 'Client must be initialized before invoking fn')
end

--- Retrieves the api of the active client. Throws an error if client not initialized.
--- @return DistantApi
local function api()
    return client().api
end

--- @class DistantFn
local M = {}

--- @param opts DistantApiAppendFileOpts
--- @param cb? fun(err?:DistantApiError, payload?:OkPayload)
--- @return DistantApiError|nil,OkPayload|nil
function M.append_file(opts, cb)
    return api():append_file(opts, cb)
end

--- @param opts DistantApiAppendFileTextOpts
--- @param cb? fun(err?:DistantApiError, payload?:OkPayload)
--- @return DistantApiError|nil,OkPayload|nil
function M.append_file_text(opts, cb)
    return api():append_file_text(opts, cb)
end

--- Loads the system information for the connected server. This will be cached
--- for future requests. Specifying `reload` as true will result in a fresh
--- request to the server for this information.
---
--- @param opts DistantClientCachedSystemInfoOpts
--- @param cb? fun(err?:DistantApiError, payload?:DistantApiSystemInfoPayload)
--- @return DistantApiError|nil, DistantApiSystemInfoPayload|nil
function M.cached_system_info(opts, cb)
    return client():cached_system_info(opts, cb)
end

--- @param opts DistantApiCapabilitiesOpts
--- @param cb? fun(err?:DistantApiError, payload?:DistantApiCapabilitiesPayload)
--- @return DistantApiError|nil,DistantApiCapabilitiesPayload|nil
function M.capabilities(opts, cb)
    return api():capabilities(opts, cb)
end

--- @param opts DistantApiCopyOpts
--- @param cb? fun(err?:DistantApiError, payload?:OkPayload)
--- @return DistantApiError|nil,OkPayload|nil
function M.copy(opts, cb)
    return api():copy(opts, cb)
end

--- @param opts DistantApiCreateDirOpts
--- @param cb? fun(err?:DistantApiError, payload?:OkPayload)
--- @return DistantApiError|nil,OkPayload|nil
function M.create_dir(opts, cb)
    return api():create_dir(opts, cb)
end

--- @param opts DistantApiExistsOpts
--- @param cb? fun(err?:DistantApiError, payload?:boolean)
--- @return DistantApiError|nil,boolean|nil
function M.exists(opts, cb)
    return api():exists(opts, cb)
end

--- @param opts DistantApiMetadataOpts
--- @param cb? fun(err?:DistantApiError, payload?:DistantApiMetadataPayload)
--- @return DistantApiError|nil,DistantApiMetadataPayload|nil
function M.metadata(opts, cb)
    return api():metadata(opts, cb)
end

--- @param opts DistantApiReadDirOpts
--- @param cb? fun(err?:DistantApiError, payload?:DistantApiReadDirPayload)
--- @return DistantApiError|nil,DistantApiReadDirPayload|nil
function M.read_dir(opts, cb)
    return api():read_dir(opts, cb)
end

--- @param opts DistantApiReadFileOpts
--- @param cb? fun(err?:DistantApiError, payload?:number[])
--- @return DistantApiError|nil,number[]|nil
function M.read_file(opts, cb)
    return api():read_file(opts, cb)
end

--- @param opts DistantApiReadFileTextOpts
--- @param cb? fun(err?:DistantApiError, payload?:string)
--- @return DistantApiError|nil,string|nil
function M.read_file_text(opts, cb)
    return api():read_file_text(opts, cb)
end

--- @param opts DistantApiRemoveOpts
--- @param cb? fun(err?:DistantApiError, payload?:OkPayload)
--- @return DistantApiError|nil,OkPayload|nil
function M.remove(opts, cb)
    return api():remove(opts, cb)
end

--- @param opts DistantApiRenameOpts
--- @param cb? fun(err?:DistantApiError, payload?:OkPayload)
--- @return DistantApiError|nil,OkPayload|nil
function M.rename(opts, cb)
    return api():rename(opts, cb)
end

--- @param opts DistantApiSearchOpts
--- @param cb? fun(err?:DistantApiError, matches?:DistantApiSearchMatch[])
--- @return DistantApiError|nil, DistantApiSearch|DistantApiSearchMatch[]|nil
function M.search(opts, cb)
    return api():search(opts, cb)
end

--- @param opts DistantApiProcessSpawnOpts
--- @param cb? fun(err?:DistantApiError, results?:DistantApiProcessSpawnResults)
--- @return DistantApiError|nil, DistantApiProcess|DistantApiProcessSpawnResults|nil
function M.spawn(opts, cb)
    return api():spawn(opts, cb)
end

--- @param opts DistantApiSystemInfoOpts
--- @param cb? fun(err?:DistantApiError, payload?:DistantApiSystemInfoPayload)
--- @return DistantApiError|nil,DistantApiSystemInfoPayload|nil
function M.system_info(opts, cb)
    return api():system_info(opts, cb)
end

--- @param opts DistantApiWriteFileOpts
--- @param cb? fun(err?:DistantApiError, payload?:OkPayload)
--- @return DistantApiError|nil,OkPayload|nil
function M.write_file(opts, cb)
    return api():write_file(opts, cb)
end

--- @param opts DistantApiWriteFileTextOpts
--- @param cb? fun(err?:DistantApiError, payload?:OkPayload)
--- @return DistantApiError|nil,OkPayload|nil
function M.write_file_text(opts, cb)
    return api():write_file_text(opts, cb)
end

--- @param opts DistantApiWatchOpts
--- @param cb fun(err?:DistantApiError, payload?:DistantApiWatchPayload)
function M.watch(opts, cb)
    api():watch(opts, cb)
end

--- @param opts DistantApiUnwatchOpts
--- @param cb? fun(err?:DistantApiError, payload?:OkPayload)
--- @return DistantApiError|nil,OkPayload|nil
function M.unwatch(opts, cb)
    return api():unwatch(opts, cb)
end

return M
