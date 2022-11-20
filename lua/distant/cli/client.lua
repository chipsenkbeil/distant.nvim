local make_api    = require('distant.cli.client.api')
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
--- @field system_info DistantSystemInfo|nil

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
    assert(instance.config.binary, 'Client missing binary')
    assert(instance.config.network, 'Client missing network')

    local repl = ClientRepl:new(instance.config)
    instance.__state = {
        api = make_api(repl),
        lsp = ClientLsp:new(instance.config),
        repl = repl,
        shell = ClientShell:new(instance.config),
        system_info = nil,
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

--- @return DistantSystemInfo
function Client:system_info()
    if self.__state.system_info == nil then
        local err, info = self:api().system_info({})
        assert(not err, err)
        assert(info, 'missing system info in response')
        self.__state.system_info = info
    end

    return self.__state.system_info
end

return Client
