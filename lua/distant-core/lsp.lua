local builder = require('distant-core.builder')
local log = require('distant-core.log')
local vars = require('distant-core.vars')

--- Represents a distant client LSP
--- @class ClientLsp
--- @field config ClientConfig
--- @field __state ClientLspState
local M = {}
M.__index = M

--- @class ClientLspState
--- @field clients table<string, string>

--- Creates a new instance of a manager of distant client LSP processes
--- @param opts ClientConfig
--- @return ClientLsp
function ClientLsp:new(opts)
    opts = opts or {}

    local instance = {}
    setmetatable(instance, ClientLsp)
    instance.config = opts
    assert(instance.config.binary, 'Lsp missing binary')
    assert(instance.config.network, 'Lsp missing network')
    instance.__state = {
        clients = {}
    }

    return instance
end

--- Connects relevant LSP client to the provided buffer, optionally
--- starting clients if needed
--- @param bufnr number Handle of the buffer where client will attach
function M.connect(bufnr)
    log.fmt_trace('lsp.connect(%s)', bufnr)

    --- @type string|nil
    local path = vars.buf(bufnr).remote_path.get()

    -- Only perform a connection if we have connected
    -- and have a remote path
    --
    -- If that's the case, we want to ensure that we only
    -- start an LSP client once per session as well as
    -- attach it to a buffer only once (not on enter)
    if path ~= nil then
        local state = require('distant-core.state')
        for label, config in pairs(state.settings.lsp) do
            -- Only apply client with a root directory that contains this file
            if vim.startswith(path, config.root_dir) then
                log.fmt_trace('File %s is within %s of %s', path, config.root_dir, label)

                -- Check if this lsp is filtered by filetype, and if so make sure that
                -- this buffer's filetype matches
                local filetypes = config.filetypes or {}
                local buf_ft = vim.api.nvim_buf_get_option(bufnr, 'filetype')
                if vim.tbl_isempty(filetypes) or vim.tbl_contains(filetypes, buf_ft) then
                    log.fmt_trace('File %s of type %s applies to %s', path, buf_ft, label)

                    -- Start the client if it doesn't exist
                    if self.__state.clients[label] == nil then
                        -- Wrap the exit so we can clear our id tracker
                        local on_exit = function(code, signal, client_id)
                            self.__state.clients[label] = nil

                            if code ~= 0 then
                                log.fmt_error('Client terminated: %s', vim.lsp.client_errors[client_id])
                            end

                            if type(config.on_exit) == 'function' then
                                config.on_exit(code, signal, client_id)
                            end
                        end

                        -- Support lsp-specific opts
                        -- TODO: This method may no longer be necessary! The cmd_cwd must be nil or a real directory,
                        --       but that will only affect our local cmd and not the actual remote cwd. So we can
                        --       set that to nil and move the cwd to our current-dir argument. Otherwise, everything
                        --       else including the root_dir should no longer need to be local as that was fixed
                        --       from what I can see between 0.5 and 0.6 in validate_clean_config!
                        log.fmt_debug('Starting LSP %s', label)

                        local cmd = builder.spawn(config.cmd)
                            :set_from_tbl(config.opts or {})
                            :set_from_tbl(self.config.network)
                            :as_list()
                        table.insert(cmd, 1, self.config.binary)
                        local id = vim.lsp.start_client(vim.tbl_deep_extend('force', config, {
                            cmd = cmd,
                            on_exit = on_exit,
                            root_dir = config.root_dir,
                        }))
                        self.__state.clients[label] = id
                    end

                    -- Attach to our buffer if it isn't already
                    local client_id = self.__state.clients[label]
                    if not vim.lsp.buf_is_attached(bufnr, client_id) then
                        log.fmt_debug('Attaching to buf %s for LSP %s', bufnr, label)
                        vim.lsp.buf_attach_client(bufnr, client_id)
                    end
                end
            end
        end
    end
end

--- @class ClientLspToCmdOpts
--- @field cmd string|string[]|nil #Optional command to use instead of default shell

--- @param opts ClientLspToCmdOpts
--- @return string[] #list representing the command separated by whitespace
function ClientLsp:to_cmd(opts)
    local c = (opts or {}).cmd
    local is_table = type(c) == 'table'
    local is_string = type(c) == 'string'
    if (is_table and vim.tbl_isempty(c)) or (is_string and vim.trim(c) == '') then
        return {}
    elseif is_table then
        c = table.concat(c, ' ')
    end

    --- @type string[]
    local cmd = Cmd.client.lsp(c):set_from_tbl(self.config.network):as_list()
    table.insert(cmd, 1, self.config.binary)

    return cmd
end

return M
