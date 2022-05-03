local Client = require('distant.client')
local settings = require('distant.settings')

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

--- Loads the active client, spawning a new client if one has not been started
--- @param opts? ClientNewOpts #Provided to newly-constructed client
--- @param cb fun(err:string|boolean, client:Client|nil)
state.load_client = function(opts, cb)
    if not state.client then
        return Client:install(opts, function(err, client)
            if err then
                return cb(err)
            end

            state.clients[client.id] = client
            state.client = client
            return cb(false, client)
        end)
    end

    return cb(false, state.client)
end

return state
