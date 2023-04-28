local builder     = require('distant-core.builder')
local make_api    = require('distant-core.cli.client.api')
local ClientLsp   = require('distant-core.cli.client.lsp')
local ClientRepl  = require('distant-core.cli.client.repl')
local ClientShell = require('distant-core.cli.client.shell')

--- Represents a distant client
--- @class DistantClient
--- @field config ClientConfig
--- @field __state ClientState
local M           = {}
M.__index         = M

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
--- @return DistantClient
function M:new(opts)
    opts = opts or {}

    local instance = {}
    setmetatable(instance, M)
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
function M:api()
    return self.__state.api
end

--- @return ClientLsp
function M:lsp()
    return self.__state.lsp
end

--- @return ClientRepl
function M:repl()
    return self.__state.repl
end

--- @return ClientShell
function M:shell()
    return self.__state.shell
end

--- @return DistantSystemInfo
function M:system_info()
    if self.__state.system_info == nil then
        local err, info = self:api().system_info({})
        assert(not err, err)
        assert(info, 'missing system info in response')
        self.__state.system_info = info
    end

    return self.__state.system_info
end

--- @class ClientWrapArgs
--- @field cmd string|string[]|nil
--- @field lsp string|string[]|nil
--- @field shell string|string[]|nil
---
--- @field cwd string|nil
--- @field env table<string,string>|nil

--- Wraps cmd, lsp, or shell to be invoked via distant. Returns
--- a string if the input is a string, or a list if the input
--- is a list.
---
--- @param args ClientWrapArgs
--- @return string|string[]
function M:wrap(args)
    args = args or {}
    args.type = args.type or 'string'

    local has_cmd = args.cmd ~= nil
    local has_lsp = args.lsp ~= nil
    local has_shell = args.shell ~= nil

    if not has_cmd and not has_lsp and not has_shell then
        error('Missing one of ["cmd", "lsp", "shell"] argument')
    elseif (has_cmd and has_lsp) or (has_cmd and has_shell) or (has_lsp and has_shell) then
        error('Can only have exactly one of ["cmd", "lsp", "shell"] argument')
    end

    --- @type string[]
    local result = {}

    if has_cmd then
        local cmd = builder.spawn(args.cmd)
        if type(args.cwd) == 'string' then
            cmd = cmd:set_current_dir(args.cwd)
        end
        if args.env then
            cmd = cmd:set_environment(args.env)
        end

        result = cmd:set_from_tbl(self.config.network):as_list()
        table.insert(result, 1, self.config.binary)
    elseif has_lsp then
        local cmd = builder.spawn(args.lsp):set_lsp()
        if args.cwd then
            cmd = cmd:set_current_dir(args.cwd)
        end
        if args.env then
            cmd = cmd:set_environment(args.env)
        end

        result = cmd:set_from_tbl(self.config.network):as_list()
        table.insert(result, 1, self.config.binary)
    elseif has_shell then
        local cmd = builder.shell(args.shell)
        if args.cwd then
            cmd = cmd:set_current_dir(args.cwd)
        end
        if args.env then
            cmd = cmd:set_environment(args.env)
        end

        result = cmd:set_from_tbl(self.config.network):as_list()
        table.insert(result, 1, self.config.binary)
    end

    -- If input was string, output will be a string
    if type(args.cmd) == 'string' or type(args.lsp) == 'string' or type(args.shell) == 'string' then
        return table.concat(result, ' ')
    else
        return result
    end
end

return M
