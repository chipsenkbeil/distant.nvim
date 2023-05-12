local state = require('distant.state')

--- Retrieves the active client. Throws an error if client not initialized.
--- @return distant.core.Client
local function client()
    return assert(state.client, 'Client must be initialized before invoking fn')
end

--- Retrieves the api of the active client. Throws an error if client not initialized.
--- @return distant.core.Api
local function api()
    return client().api
end

--- @class distant.Fn
local M = {}

--- Returns whether or not `fn` is ready for use.
--- @return boolean
function M.is_ready()
    return state.client ~= nil
end

--- @param opts distant.core.api.AppendFileOpts
--- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.OkPayload)
--- @return distant.core.api.Error|nil,distant.core.api.OkPayload|nil
function M.append_file(opts, cb)
    return api():append_file(opts, cb)
end

--- @param opts distant.core.api.AppendFileTextOpts
--- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.OkPayload)
--- @return distant.core.api.Error|nil,distant.core.api.OkPayload|nil
function M.append_file_text(opts, cb)
    return api():append_file_text(opts, cb)
end

--- Loads the system information for the connected server. This will be cached
--- for future requests. Specifying `reload` as true will result in a fresh
--- request to the server for this information.
---
--- @param opts distant.client.CachedSystemInfoOpts
--- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.SystemInfoPayload)
--- @return distant.core.api.Error|nil, distant.core.api.SystemInfoPayload|nil
function M.cached_system_info(opts, cb)
    return client():cached_system_info(opts, cb)
end

--- @param opts distant.core.api.CapabilitiesOpts
--- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.CapabilitiesPayload)
--- @return distant.core.api.Error|nil,distant.core.api.CapabilitiesPayload|nil
function M.capabilities(opts, cb)
    return api():capabilities(opts, cb)
end

--- @param opts distant.core.api.CopyOpts
--- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.OkPayload)
--- @return distant.core.api.Error|nil,distant.core.api.OkPayload|nil
function M.copy(opts, cb)
    return api():copy(opts, cb)
end

--- @param opts distant.core.api.CreateDirOpts
--- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.OkPayload)
--- @return distant.core.api.Error|nil,distant.core.api.OkPayload|nil
function M.create_dir(opts, cb)
    return api():create_dir(opts, cb)
end

--- @param opts distant.core.api.ExistsOpts
--- @param cb? fun(err?:distant.core.api.Error, payload?:boolean)
--- @return distant.core.api.Error|nil,boolean|nil
function M.exists(opts, cb)
    return api():exists(opts, cb)
end

--- @param opts distant.core.api.MetadataOpts
--- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.MetadataPayload)
--- @return distant.core.api.Error|nil,distant.core.api.MetadataPayload|nil
function M.metadata(opts, cb)
    return api():metadata(opts, cb)
end

--- @param opts distant.core.api.ReadDirOpts
--- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.ReadDirPayload)
--- @return distant.core.api.Error|nil,distant.core.api.ReadDirPayload|nil
function M.read_dir(opts, cb)
    return api():read_dir(opts, cb)
end

--- @param opts distant.core.api.ReadFileOpts
--- @param cb? fun(err?:distant.core.api.Error, payload?:number[])
--- @return distant.core.api.Error|nil,number[]|nil
function M.read_file(opts, cb)
    return api():read_file(opts, cb)
end

--- @param opts distant.core.api.ReadFileTextOpts
--- @param cb? fun(err?:distant.core.api.Error, payload?:string)
--- @return distant.core.api.Error|nil,string|nil
function M.read_file_text(opts, cb)
    return api():read_file_text(opts, cb)
end

--- @param opts distant.core.api.RemoveOpts
--- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.OkPayload)
--- @return distant.core.api.Error|nil,distant.core.api.OkPayload|nil
function M.remove(opts, cb)
    return api():remove(opts, cb)
end

--- @param opts distant.core.api.RenameOpts
--- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.OkPayload)
--- @return distant.core.api.Error|nil,distant.core.api.OkPayload|nil
function M.rename(opts, cb)
    return api():rename(opts, cb)
end

--- @param opts distant.core.api.SearchOpts
--- @param cb? fun(err?:distant.core.api.Error, matches?:distant.core.api.search.Match[])
--- @return distant.core.api.Error|nil, distant.core.api.Searcher|distant.core.api.search.Match[]|nil
function M.search(opts, cb)
    return api():search(opts, cb)
end

--- @param opts distant.core.api.process.SpawnOpts
--- @param cb? fun(err?:distant.core.api.Error, results?:distant.core.api.process.SpawnResults)
--- @return distant.core.api.Error|nil, distant.core.api.Process|distant.core.api.process.SpawnResults|nil
function M.spawn(opts, cb)
    return api():spawn(opts, cb)
end

--- @param opts distant.core.api.SystemInfoOpts
--- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.SystemInfoPayload)
--- @return distant.core.api.Error|nil,distant.core.api.SystemInfoPayload|nil
function M.system_info(opts, cb)
    return api():system_info(opts, cb)
end

--- @param opts distant.core.api.WriteFileOpts
--- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.OkPayload)
--- @return distant.core.api.Error|nil,distant.core.api.OkPayload|nil
function M.write_file(opts, cb)
    return api():write_file(opts, cb)
end

--- @param opts distant.core.api.WriteFileTextOpts
--- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.OkPayload)
--- @return distant.core.api.Error|nil,distant.core.api.OkPayload|nil
function M.write_file_text(opts, cb)
    return api():write_file_text(opts, cb)
end

--- @param opts distant.core.api.WatchOpts
--- @param cb fun(err?:distant.core.api.Error, payload?:distant.core.api.WatchPayload)
function M.watch(opts, cb)
    api():watch(opts, cb)
end

--- @param opts distant.core.api.UnwatchOpts
--- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.OkPayload)
--- @return distant.core.api.Error|nil,distant.core.api.OkPayload|nil
function M.unwatch(opts, cb)
    return api():unwatch(opts, cb)
end

return M
