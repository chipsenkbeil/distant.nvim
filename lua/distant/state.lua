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
state.load_settings = function(label)
    state.settings = settings.for_label(label)
end

--- Loads the active client, spawning a new client if one has not been started
--- @param opts ClientNewOpts @Provided to newly-constructed client
--- @return Client
state.load_client = function(opts)
    if not state.client then
        local client = Client:new(opts)
        state.clients[client.id] = client
        state.client = client
    end

    return state.client
end

return state
