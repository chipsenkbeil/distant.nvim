local make_api    = require('distant-core.cli.client.api')
local ClientLsp   = require('distant-core.cli.client.lsp')
local ClientRepl  = require('distant-core.cli.client.repl')
local ClientShell = require('distant-core.cli.client.shell')
local Cmd         = require('distant-core.cli.cmd')

--- Represents a distant client
--- @class Client
--- @field config ClientConfig
--- @field __state ClientState
local Client      = {}
Client.__index    = Client

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
function Client:wrap(args)
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
        -- Get the command as a string
        local cmd = args.cmd or ''
        if type(cmd) == 'table' then
            cmd = table.concat(cmd, ' ')
        end

        local subcmd = Cmd.client.action_cmd.spawn(cmd)
        if type(args.cwd) == 'string' then
            subcmd = subcmd:set_current_dir(args.cwd)
        end
        if args.env then
            subcmd = subcmd:set_environment(args.env)
        end

        result = Cmd.client.action(subcmd):set_from_tbl(self.config.network):as_list()
        table.insert(result, 1, self.config.binary)
    elseif has_lsp then
        -- Get the lsp as a string
        local lsp = args.lsp or ''
        if type(lsp) == 'table' then
            lsp = table.concat(lsp, ' ')
        end

        local cmd = Cmd.client.lsp(lsp)
        if args.cwd then
            cmd = cmd:set_current_dir(args.cwd)
        end

        result = cmd:set_from_tbl(self.config.network):as_list()
        table.insert(result, 1, self.config.binary)
    elseif has_shell then
        -- Get the shell as a string
        local shell = args.shell or ''
        if type(shell) == 'table' then
            shell = table.concat(shell, ' ')
        end

        local cmd = Cmd.client.shell(shell)
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

return Client
