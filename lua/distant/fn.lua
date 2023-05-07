local state = require('distant.state')

--- Retrieves the active client. Throws an error if client not initialized.
--- @return distant.Client
local function client()
    return assert(state.client, 'Client must be initialized before invoking fn')
end

--- Retrieves the api of the active client. Throws an error if client not initialized.
--- @return distant.client.Api
local function api()
    return client().api
end

--- @class DistantFn
local M = {}

--- @param opts distant.client.api.AppendFileOpts
--- @param cb? fun(err?:distant.api.Error, payload?:distant.client.api.OkPayload)
--- @return distant.api.Error|nil,distant.client.api.OkPayload|nil
function M.append_file(opts, cb)
    return api():append_file(opts, cb)
end

--- @param opts distant.client.api.AppendFileTextOpts
--- @param cb? fun(err?:distant.api.Error, payload?:distant.client.api.OkPayload)
--- @return distant.api.Error|nil,distant.client.api.OkPayload|nil
function M.append_file_text(opts, cb)
    return api():append_file_text(opts, cb)
end

--- Loads the system information for the connected server. This will be cached
--- for future requests. Specifying `reload` as true will result in a fresh
--- request to the server for this information.
---
--- @param opts distant.client.CachedSystemInfoOpts
--- @param cb? fun(err?:distant.api.Error, payload?:distant.client.api.SystemInfoPayload)
--- @return distant.api.Error|nil, distant.client.api.SystemInfoPayload|nil
function M.cached_system_info(opts, cb)
    return client():cached_system_info(opts, cb)
end

--- @param opts distant.client.api.CapabilitiesOpts
--- @param cb? fun(err?:distant.api.Error, payload?:distant.client.api.CapabilitiesPayload)
--- @return distant.api.Error|nil,distant.client.api.CapabilitiesPayload|nil
function M.capabilities(opts, cb)
    return api():capabilities(opts, cb)
end

--- @param opts distant.client.api.CopyOpts
--- @param cb? fun(err?:distant.api.Error, payload?:distant.client.api.OkPayload)
--- @return distant.api.Error|nil,distant.client.api.OkPayload|nil
function M.copy(opts, cb)
    return api():copy(opts, cb)
end

--- @param opts distant.client.api.CreateDirOpts
--- @param cb? fun(err?:distant.api.Error, payload?:distant.client.api.OkPayload)
--- @return distant.api.Error|nil,distant.client.api.OkPayload|nil
function M.create_dir(opts, cb)
    return api():create_dir(opts, cb)
end

--- @param opts distant.client.api.ExistsOpts
--- @param cb? fun(err?:distant.api.Error, payload?:boolean)
--- @return distant.api.Error|nil,boolean|nil
function M.exists(opts, cb)
    return api():exists(opts, cb)
end

--- @param opts distant.client.api.MetadataOpts
--- @param cb? fun(err?:distant.api.Error, payload?:distant.client.api.MetadataPayload)
--- @return distant.api.Error|nil,distant.client.api.MetadataPayload|nil
function M.metadata(opts, cb)
    return api():metadata(opts, cb)
end

--- @param opts distant.client.api.ReadDirOpts
--- @param cb? fun(err?:distant.api.Error, payload?:distant.client.api.ReadDirPayload)
--- @return distant.api.Error|nil,distant.client.api.ReadDirPayload|nil
function M.read_dir(opts, cb)
    return api():read_dir(opts, cb)
end

--- @param opts distant.client.api.ReadFileOpts
--- @param cb? fun(err?:distant.api.Error, payload?:number[])
--- @return distant.api.Error|nil,number[]|nil
function M.read_file(opts, cb)
    return api():read_file(opts, cb)
end

--- @param opts distant.client.api.ReadFileTextOpts
--- @param cb? fun(err?:distant.api.Error, payload?:string)
--- @return distant.api.Error|nil,string|nil
function M.read_file_text(opts, cb)
    return api():read_file_text(opts, cb)
end

--- @param opts distant.client.api.RemoveOpts
--- @param cb? fun(err?:distant.api.Error, payload?:distant.client.api.OkPayload)
--- @return distant.api.Error|nil,distant.client.api.OkPayload|nil
function M.remove(opts, cb)
    return api():remove(opts, cb)
end

--- @param opts distant.client.api.RenameOpts
--- @param cb? fun(err?:distant.api.Error, payload?:distant.client.api.OkPayload)
--- @return distant.api.Error|nil,distant.client.api.OkPayload|nil
function M.rename(opts, cb)
    return api():rename(opts, cb)
end

--- @param opts distant.client.api.SearchOpts
--- @param cb? fun(err?:distant.api.Error, matches?:distant.client.api.search.Match[])
--- @return distant.api.Error|nil, distant.client.api.Searcher|distant.client.api.search.Match[]|nil
function M.search(opts, cb)
    return api():search(opts, cb)
end

--- @param opts distant.client.api.process.SpawnOpts
--- @param cb? fun(err?:distant.api.Error, results?:distant.client.api.process.SpawnResults)
--- @return distant.api.Error|nil, distant.client.api.Process|distant.client.api.process.SpawnResults|nil
function M.spawn(opts, cb)
    return api():spawn(opts, cb)
end

--- @param opts distant.client.api.SystemInfoOpts
--- @param cb? fun(err?:distant.api.Error, payload?:distant.client.api.SystemInfoPayload)
--- @return distant.api.Error|nil,distant.client.api.SystemInfoPayload|nil
function M.system_info(opts, cb)
    return api():system_info(opts, cb)
end

--- @param opts distant.client.api.WriteFileOpts
--- @param cb? fun(err?:distant.api.Error, payload?:distant.client.api.OkPayload)
--- @return distant.api.Error|nil,distant.client.api.OkPayload|nil
function M.write_file(opts, cb)
    return api():write_file(opts, cb)
end

--- @param opts distant.client.api.WriteFileTextOpts
--- @param cb? fun(err?:distant.api.Error, payload?:distant.client.api.OkPayload)
--- @return distant.api.Error|nil,distant.client.api.OkPayload|nil
function M.write_file_text(opts, cb)
    return api():write_file_text(opts, cb)
end

--- @param opts distant.client.api.WatchOpts
--- @param cb fun(err?:distant.api.Error, payload?:distant.client.api.WatchPayload)
function M.watch(opts, cb)
    api():watch(opts, cb)
end

--- @param opts distant.client.api.UnwatchOpts
--- @param cb? fun(err?:distant.api.Error, payload?:distant.client.api.OkPayload)
--- @return distant.api.Error|nil,distant.client.api.OkPayload|nil
function M.unwatch(opts, cb)
    return api():unwatch(opts, cb)
end

return M
