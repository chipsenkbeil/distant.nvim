local ClientApi   = require('distant.cli.client.api')
local ClientLsp   = require('distant.cli.client.lsp')
local ClientRepl  = require('distant.cli.client.repl')
local ClientShell = require('distant.cli.client.shell')

--- Represents a distant client
--- @class Client
--- @field config ClientConfig
--- @field __state ClientState
local Client = {}
Client.__index = Client

--- @class ClientConfig
--- @field binary string #path to distant binary to use
--- @field network ClientNetwork #client-specific network settings

--- @class ClientNetwork
--- @field connection string|nil #id of the connection tied to the client
--- @field unix_socket string|nil #path to the unix socket of the manager
--- @field windows_pipe string|nil #name of the windows pipe of the manager

--- @class ClientState
--- @field api ClientApi
--- @field lsp ClientLsp
--- @field repl ClientRepl
--- @field shell ClientShell

--- Creates a new instance of a distant client
--- @param opts ClientConfig
--- @return Client
function Client:new(opts)
    opts = opts or {}

    local instance = {}
    setmetatable(instance, Client)
    instance.config = {
        binary = opts.binary,
        network = vim.deepcopy(opts.network) or {},
    }

    local repl = ClientRepl:new(self.config)
    instance.__state = {
        api = ClientApi:new(repl),
        lsp = ClientLsp:new(self.config),
        repl = repl,
        shell = ClientShell:new(self.config),
    }

    return instance
end

--- @return ClientApi
function Client:api()
    return self.__state.api
end

--- @return ClientLsp
function Client:lsp()
    return self.__state.lsp
end

--- @return ClientRepl
function Client:repl()
    return self.__state.repl
end

--- @return ClientShell
function Client:shell()
    return self.__state.shell
end

return Client
