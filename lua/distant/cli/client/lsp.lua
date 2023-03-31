local log = require('distant.log')
local vars = require('distant.vars')

local Cmd = require('distant.cli.cmd')

--- Represents a distant client LSP
--- @class ClientLsp
--- @field config ClientConfig
--- @field __state ClientLspState
local ClientLsp = {}
ClientLsp.__index = ClientLsp

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

--- Wraps `vim.lsp.start_client`, injecting necessary details to run the
--- LSP binary on the connected remote machine while acquiring and
--- visualizing results on the local machine
---
--- @param config table The configuration to use with the LSP client,
---        mirring that of `vim.lsp.start_client`
--- @param opts table Additional options to use for the distant binary
---        acting as a proxy such as `log_file` or `log_level`
--- @return number #The id of the created client
function ClientLsp:__lsp_start_client(config, opts)
    opts = opts or {}
    log.fmt_trace('lsp_start_client(%s, %s)', config, opts)

    -- The command needs to be wrapped with a prefix that is our distant binary
    -- as we are running the actual lsp server remotely
    local config_cmd = config.cmd
    if type(config_cmd) == 'table' then
        config_cmd = table.concat(config_cmd, ' ')
    end

    -- If no current directory provided, use the root directory
    if not opts.current_dir then
        opts.current_dir = config.root_dir
    end

    --- @type string[]
    local cmd = Cmd.client.lsp(config_cmd):set_from_tbl(opts):set_from_tbl(self.config.network):as_list()
    table.insert(cmd, 1, self.config.binary)

    -- TODO: Followed this based on nvim-lspconfig, but don't yet understand
    --       the workspace configuration override
    local capabilities = config.capabilities or vim.lsp.protocol.make_client_capabilities();
    capabilities = vim.tbl_deep_extend('force', capabilities, {
        workspace = {
            configuration = true,
        }
    })

    -- NOTE: root_dir is enforced as a directory on the local machine, but now that our
    --       lsp instances are remote, there is no guarantee that the path is a directory
    --       or exists at all. To that end, we must explicitly remove root_dir AND
    --       the workspace_folders (if provided) and fill in '/' as the root_dir, swapping
    --       back in the actual root dir and workspace folders during pre-init
    --       in the form of `rootPath`, `rootUri`, and `workspaceFolders`
    local function before_init(params, _config)
        params.rootPath = config.root_dir
        params.rootUri = vim.uri_from_fname(config.root_dir)

        if not config.workspace_folders then
            params.workspaceFolders = { {
                uri = vim.uri_from_fname(config.root_dir);
                name = string.format('%s', config.root_dir);
            } }
        else
            params.workspaceFolders = config.workspace_folders
        end

        if type(config.before_init) == 'function' then
            config.before_init(params, _config)
        end
    end

    -- Override the config's cmd, init_options, and capabilities
    -- as we take those existing config fields and alter them to work on
    -- a remote machine
    local lsp_config = vim.tbl_deep_extend(
        'force',
        config,
        {
            before_init = before_init;
            cmd = cmd;
            capabilities = capabilities;

            -- Must zero these out to ensure that we pass validation
            -- TODO: Support Windows local machine
            root_dir = '/';
            workspace_folders = nil;
        }
    )
    return vim.lsp.start_client(lsp_config)
end

--- Connects relevant LSP client to the provided buffer, optionally
--- starting clients if needed
--- @param buf number Handle of the buffer where client will attach
function ClientLsp:connect(buf)
    log.fmt_trace('lsp.connect(%s)', buf)

    --- @type string|nil
    local path = vars.buf(buf).remote_path.get()

    -- Only perform a connection if we have connected
    -- and have a remote path
    --
    -- If that's the case, we want to ensure that we only
    -- start an LSP client once per session as well as
    -- attach it to a buffer only once (not on enter)
    if path ~= nil then
        local state = require('distant.state')
        for label, config in pairs(state.settings.lsp) do
            -- Only apply client with a root directory that contains this file
            if vim.startswith(path, config.root_dir) then
                log.fmt_trace('File %s is within %s of %s', path, config.root_dir, label)

                -- Check if this lsp is filtered by filetype, and if so make sure that
                -- this buffer's filetype matches
                local filetypes = config.filetypes or {}
                local buf_ft = vim.api.nvim_buf_get_option(buf, 'filetype')
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
                        log.fmt_debug('Starting LSP %s', label)
                        local id = self:__lsp_start_client(
                            vim.tbl_deep_extend('force', config, { on_exit = on_exit }),
                            opts
                        )
                        self.__state.clients[label] = id
                    end

                    -- Attach to our buffer if it isn't already
                    local client_id = self.__state.clients[label]
                    if not vim.lsp.buf_is_attached(buf, client_id) then
                        log.fmt_debug('Attaching to buf %s for LSP %s', buf, label)
                        vim.lsp.buf_attach_client(buf, client_id)
                    end
                end
            end
        end
    end
end

return ClientLsp
