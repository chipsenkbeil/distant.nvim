local plugin = require('distant')

--- Creates an instance of the API that works with the specified client id.
--- If no client id is provided, this will use the active client held by the plugin.
---
--- @param client_id? distant.core.manager.ConnectionId
--- @return distant.plugin.Api
local function make_api(client_id)
    --- Retrieves the active client. Throws an error if client not initialized.
    --- @return distant.core.Client
    local function client()
        return assert(plugin:client(client_id),
            client_id ~= nil
            and ('No client available with id ' .. client_id .. '!')
            or 'No active client available!'
        )
    end

    --- Retrieves the api of the active client. Throws an error if client not initialized.
    --- @return distant.core.Api
    local function api()
        return client().api
    end

    --------------------------------------------------------------------------
    -- CLASS DEFINITION
    --------------------------------------------------------------------------

    --- Interface to use the API methods of the plugin.
    --
    --- Can be called like a function and provided a client id in order to operate
    --- with a specific client, otherwise defaults to the active client.
    ---
    --- @class distant.plugin.Api
    --- @operator call(string|nil):distant.plugin.Api
    local M = {}
    setmetatable(M, {
        --- @param _ distant.plugin.Api
        --- @param client_id? distant.core.manager.ConnectionId
        --- @return distant.plugin.Api
        __call = function(_, client_id)
            assert(
                client_id == nil or type(client_id) == 'number',
                ('api() given invalid value: %s'):format(vim.inspect(client_id))
            )
            return make_api(client_id)
        end
    })

    --------------------------------------------------------------------------
    -- UTILITY METHODS
    --------------------------------------------------------------------------

    --- Returns whether or not the api is ready for use.
    --- @return boolean
    function M.is_ready()
        return plugin:client(client_id) ~= nil
    end

    --- Returns the client id tied to this API, or nil if using the active client.
    --- @return distant.core.manager.ConnectionId|nil
    function M.client_id()
        return client_id
    end

    --------------------------------------------------------------------------
    -- BATCH API
    --------------------------------------------------------------------------

    --- Sends a series of API requests together as a single batch.
    ---
    --- * `opts` - list of requests to send as well as specific options that can be passed.
    --- * `opts.timeout` - maximum time (in milliseconds) to wait for a synchronous response.
    --- * `opts.interval` - time (in milliseconds) between polls for completion for a synchronous response.
    ---
    --- # Synchronous Example
    ---
    --- ```lua
    --- local err, results = api.batch({
    ---     { type = 'exists', path = '/path/to/file1.txt' },
    ---     { type = 'exists', path = '/path/to/file2.txt' },
    ---     { type = 'metadata', path = '/path/to/file3.txt' },
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
    ---     { type = 'exists', path = '/path/to/file1.txt' },
    ---     { type = 'exists', path = '/path/to/file2.txt' },
    ---     { type = 'metadata', path = '/path/to/file3.txt' },
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
    --- @param opts {[number]: table, sequence?:boolean, timeout?:number, interval?:number}
    --- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.batch.Response[])
    --- @return distant.core.api.Error|nil err, distant.core.batch.Response[]|nil payload
    function M.batch(opts, cb)
        return api():batch(opts, cb)
    end

    --------------------------------------------------------------------------
    -- DISTANT API
    --------------------------------------------------------------------------

    --- @param opts distant.core.api.AppendFileOpts
    --- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.OkPayload)
    --- @return distant.core.api.Error|nil err, distant.core.api.OkPayload|nil payload
    function M.append_file(opts, cb)
        return api():append_file(opts, cb)
    end

    --- @param opts distant.core.api.AppendFileTextOpts
    --- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.OkPayload)
    --- @return distant.core.api.Error|nil err, distant.core.api.OkPayload|nil payload
    function M.append_file_text(opts, cb)
        return api():append_file_text(opts, cb)
    end

    --- Loads the system information for the connected server. This will be cached
    --- for future requests. Specifying `reload` as true will result in a fresh
    --- request to the server for this information.
    ---
    --- @param opts distant.core.client.CachedSystemInfoOpts
    --- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.SystemInfoPayload)
    --- @return distant.core.api.Error|nil err, distant.core.api.SystemInfoPayload|nil payload
    function M.cached_system_info(opts, cb)
        return client():cached_system_info(opts, cb)
    end

    --- @param opts distant.core.api.CopyOpts
    --- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.OkPayload)
    --- @return distant.core.api.Error|nil err, distant.core.api.OkPayload|nil payload
    function M.copy(opts, cb)
        return api():copy(opts, cb)
    end

    --- @param opts distant.core.api.CreateDirOpts
    --- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.OkPayload)
    --- @return distant.core.api.Error|nil err, distant.core.api.OkPayload|nil payload
    function M.create_dir(opts, cb)
        return api():create_dir(opts, cb)
    end

    --- @param opts distant.core.api.ExistsOpts
    --- @param cb? fun(err?:distant.core.api.Error, payload?:boolean)
    --- @return distant.core.api.Error|nil err, boolean|nil exists
    function M.exists(opts, cb)
        return api():exists(opts, cb)
    end

    --- @param opts distant.core.api.MetadataOpts
    --- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.MetadataPayload)
    --- @return distant.core.api.Error|nil err, distant.core.api.MetadataPayload|nil metadata
    function M.metadata(opts, cb)
        return api():metadata(opts, cb)
    end

    --- @param opts distant.core.api.ReadDirOpts
    --- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.ReadDirPayload)
    --- @return distant.core.api.Error|nil err, distant.core.api.ReadDirPayload|nil payload
    function M.read_dir(opts, cb)
        return api():read_dir(opts, cb)
    end

    --- @param opts distant.core.api.ReadFileOpts
    --- @param cb? fun(err?:distant.core.api.Error, payload?:number[])
    --- @return distant.core.api.Error|nil err, number[]|nil bytes
    function M.read_file(opts, cb)
        return api():read_file(opts, cb)
    end

    --- @param opts distant.core.api.ReadFileTextOpts
    --- @param cb? fun(err?:distant.core.api.Error, payload?:string)
    --- @return distant.core.api.Error|nil err, string|nil text
    function M.read_file_text(opts, cb)
        return api():read_file_text(opts, cb)
    end

    --- @param opts distant.core.api.RemoveOpts
    --- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.OkPayload)
    --- @return distant.core.api.Error|nil err, distant.core.api.OkPayload|nil payload
    function M.remove(opts, cb)
        return api():remove(opts, cb)
    end

    --- @param opts distant.core.api.RenameOpts
    --- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.OkPayload)
    --- @return distant.core.api.Error|nil err, distant.core.api.OkPayload|nil payload
    function M.rename(opts, cb)
        return api():rename(opts, cb)
    end

    --- @param opts distant.core.api.SearchOpts
    --- @param cb? fun(err?:distant.core.api.Error, matches?:distant.core.api.search.Match[])
    --- @return distant.core.api.Error|nil err, distant.core.api.Searcher|distant.core.api.search.Match[]|nil searcher_or_matches
    function M.search(opts, cb)
        return api():search(opts, cb)
    end

    --- @param opts distant.core.api.process.SpawnOpts
    --- @param cb? fun(err?:distant.core.api.Error, results?:distant.core.api.process.SpawnResults)
    --- @return distant.core.api.Error|nil err, distant.core.api.Process|distant.core.api.process.SpawnResults|nil process_or_results
    function M.spawn(opts, cb)
        return api():spawn(opts, cb)
    end

    --- @param opts distant.core.api.SystemInfoOpts
    --- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.SystemInfoPayload)
    --- @return distant.core.api.Error|nil err, distant.core.api.SystemInfoPayload|nil system_info
    function M.system_info(opts, cb)
        return api():system_info(opts, cb)
    end

    --- @param opts distant.core.api.WriteFileOpts
    --- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.OkPayload)
    --- @return distant.core.api.Error|nil err, distant.core.api.OkPayload|nil payload
    function M.write_file(opts, cb)
        return api():write_file(opts, cb)
    end

    --- @param opts distant.core.api.WriteFileTextOpts
    --- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.OkPayload)
    --- @return distant.core.api.Error|nil err, distant.core.api.OkPayload|nil payload
    function M.write_file_text(opts, cb)
        return api():write_file_text(opts, cb)
    end

    --- @param opts distant.core.api.watcher.WatchOpts
    --- @param cb? fun(err?:distant.core.api.Error, watcher?:distant.core.api.Watcher)
    --- @return distant.core.api.Error|nil err, distant.core.api.Watcher|nil watcher
    function M.watch(opts, cb)
        api():watch(opts, cb)
    end

    --- @param opts distant.core.api.UnwatchOpts
    --- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.OkPayload)
    --- @return distant.core.api.Error|nil err, distant.core.api.OkPayload|nil payload
    function M.unwatch(opts, cb)
        return api():unwatch(opts, cb)
    end

    --- @param opts distant.core.api.VersionOpts
    --- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.VersionPayload)
    --- @return distant.core.api.Error|nil err, distant.core.api.VersionPayload|nil version
    function M.version(opts, cb)
        return api():version(opts, cb)
    end

    return M
end

return make_api()
