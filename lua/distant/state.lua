local settings = require('distant.settings')
local utils = require('distant.utils')

--- @class State
--- @field client Client|nil
--- @field clients table<string, Client>
--- @field settings Settings
local state = {
    -- Contains active client
    client = nil;

    -- Contains all clients mapped by id
    clients = {};

    -- Set default settings so we don't get nil access errors even when no
    -- launch call has been made yet
    settings = settings.default();
}

--- Loads into state the settings appropriate for the remote machine with the give label
--- @return Settings
state.load_settings = function(label)
    state.settings = settings.for_label(label)
    return state.settings
end

--- Spawns new client and sets it as the active client
--- @overload fun():boolean|string, Client|nil
--- @overload fun(opts:ClientNewOpts):boolean|string, Client|nil
--- @overload fun(cb:fun(err:string|boolean, client:Client|nil))
---
--- @param opts ClientNewOpts #Provided to newly-constructed client
--- @param cb fun(err:string|boolean, client:Client|nil)
state.new_client = function(opts, cb)
    if not cb and type(opts) == 'function' then
        cb = opts
        opts = {}
    end

    opts = opts or {}

    local rx
    if not cb then
        cb, rx = utils.oneshot_channel(
            opts.timeout or state.settings.max_timeout,
            opts.interval or state.settings.timeout_interval
        )
    end

    local Client = require('distant.client')
    Client:install(opts, function(err, client)
        if err then
            return cb(err)
        end

        --- NOTE: At this point, we can assume the client is not nil
        --- @type Client
        client = client

        state.clients[client.id] = client
        state.client = client
        return cb(false, client)
    end)


    -- If we have a receiver, this indicates that we are synchronous
    if rx then
        local err1, err2, result = rx()
        return err1 or err2, result
    end
end

--- Loads the active client, spawning a new client if one has not been started
--- @overload fun():boolean|string, Client|nil
--- @overload fun(opts:ClientNewOpts):boolean|string, Client|nil
--- @overload fun(cb:fun(err:string|boolean, client:Client|nil))
---
--- @param opts ClientNewOpts #Provided to newly-constructed client
--- @param cb fun(err:string|boolean, client:Client|nil)
state.load_client = function(opts, cb)
    if not cb and type(opts) == 'function' then
        cb = opts
        opts = {}
    end

    opts = opts or {}

    local rx
    if not cb then
        cb, rx = utils.oneshot_channel(
            opts.timeout or state.settings.max_timeout,
            opts.interval or state.settings.timeout_interval
        )
    end

    if not state.client then
        state.new_client(opts, cb)
    else
        cb(false, state.client)
    end


    -- If we have a receiver, this indicates that we are synchronous
    if rx then
        local err1, err2, result = rx()
        return err1 or err2, result
    end
end

return state
