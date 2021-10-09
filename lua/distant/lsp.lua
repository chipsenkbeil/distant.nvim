local log = require('distant.log')
local lib = require('distant.lib')
local state = require('distant.state')
local u = require('distant.utils')
local v = require('distant.vars')

--- Contains operations to apply against LSP instances on remote machines
local lsp = {
    __clients = {};
}

--- Wraps `vim.lsp.start_client`, injecting necessary details to run the
--- LSP binary on the connected remote machine while acquiring and
--- visualizing results on the local machine
---
--- @param config table The configuration to use with the LSP client,
---        mirring that of `vim.lsp.start_client`
--- @param opts table Additional options to use for the distant binary
---        acting as a proxy such as `log_file` or `log_level`
--- @return number #The id of the created client
local function lsp_start_client(config, opts)
    assert(type(config) == 'table', 'config must be a table')
    assert(config.cmd, 'cmd is required')
    assert(config.root_dir, 'root_dir is required')
    opts = opts or {}
    log.fmt_trace('lsp_start_client(%s, %s)', config, opts)

    -- TODO: If no log file is specified for output, we need to make our process quiet
    --       otherwise invalid data can be fed to the LSP client somehow; this shouldn't
    --       be the case as our proxy outputs logs into stderr and not stdout, but
    --       maybe the client is reading both
    if not opts.log_file then
        opts.quiet = true
    end

    local session = assert(state.session, 'Session not yet established! Launch first!')

    -- Build our extra arguments for the distant binary
    local args = vim.split(u.build_arg_str(opts), ' ', true)

    -- The command needs to be wrapped with a prefix that is our distant binary
    -- as we are running the actual lsp server remotely
    local cmd = {
        state.settings.binary_name,
        'lsp',
        '--format', 'shell',
        '--session', 'lsp',
    }
    cmd = vim.list_extend(cmd, args)
    cmd = vim.list_extend(cmd, {'--'})

    -- Finally add the config command that we are wrapping, transforming a string
    -- into a list split by space if needed
    local config_cmd = config.cmd
    if type(config_cmd) == 'string' then
        config_cmd = vim.split(config_cmd, ' ', true)
    end
    cmd = vim.list_extend(cmd, config_cmd)

    local capabilities = config.capabilities or vim.lsp.protocol.make_client_capabilities();
    capabilities = u.merge(capabilities, {
        workspace = {
          configuration = true,
        }
    })

    -- NOTE: root_dir is enforced as a directory on the local machine, but now
    -- that our lsp instances are remote, there is no guarantee that the path
    -- is a directory or exists at all. To that end, we must explicitly remove
    -- root_dir AND the workspace_folders (if provided) and fill in '/' as the
    -- root_dir, swapping back in the actual root dir and workspace folders
    -- during pre-init in the form of `rootPath`, `rootUri`, and
    -- `workspaceFolders`
    local function before_init(params, _config)
        params.rootPath = config.root_dir
        params.rootUri = vim.uri_from_fname(config.root_dir)

        if not config.workspace_folders then
            params.workspaceFolders = {{
                uri = vim.uri_from_fname(config.root_dir);
                name = string.format('%s', config.root_dir);
            }}
        else
            params.workspaceFolders = config.workspace_folders
        end

        if type(config.before_init) == 'function' then
            config.before_init(params, _config)
        end
    end

    -- Override the config's cmd, and capabilities as we take those existing
    -- config fields and alter them to work on a remote machine
    local lsp_config = u.merge(
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

    -- NOTE: Need to overwrite uv.spawn (aka vim.loop.spawn) temporarily
    local uv_spawn = vim.loop.spawn
    vim.loop.spawn = function(cmd, spawn_params, on_exit)
        -- cmd = string
        -- spawn_params = {
        --     args = cmd_args;
        --     stdio = {stdin, stdout, stderr};
        -- }
        -- on_exit = function(code, signal) where
        --     * code = exit code
        --     * signal = signal used to terminate (if any)
        local pid = 123
        local handle = {
            is_closing = function()
                -- returns bool
            end,
            close = function(cb)
                -- cb() (optional) when done
                -- returns nothing
            end,
            kill = function(_signum)
                -- Only ever sends 15, which is sigterm
                -- returns 0 or fail
            end,
        }
        return handle, pid
    end

    -- NOTE: Need to overwrite uv.new_pipe (aka vim.loop.new_pipe) temporarily
    local uv_new_pipe = vim.loop.new_pipe
    vim.loop.new_pipe = function(_ipc)
        return {
            -- Private function used to set the pipe from within the uv.spawn wrapper
            __set = function()
            end,

            read_start = function(cb)
                -- cb(err = string|nil, data = string|nil)
                -- returns 0 or fail
            end,
            write = function(data, cb)
                -- data = string, cb = function() (optional) when done
                -- returns uv_write_t (unused) or fail
            end
        }
    end

    -- Start the client and restore uv functions
    local success, res = pcall(vim.lsp.start_client, lsp_config)
    vim.loop.spawn = uv_spawn
    vim.loop.new_pipe = uv_new_pipe

    assert(success, res)
    return res
end

--- Connects relevant LSP clients to the provided buffer, optionally
--- starting clients if needed
--- @param buf number Handle of the buffer where clients will attach
lsp.connect = function(buf)
    log.fmt_trace('lsp.connect(%s)', buf)
    local path = v.buf.remote_path(buf)

    -- Only perform a connection if we have connected
    -- and have a remote path
    --
    -- If that's the case, we want to ensure that we only
    -- start an LSP client once per session as well as
    -- attach it to a buffer only once (not on enter)
    if path ~= nil then
        for label, config in pairs(state.settings.lsp) do
            -- Only apply clients with a root directory that contains this file
            if vim.startswith(path, config.root_dir) then
                log.fmt_trace('File %s is within %s of %s', path, config.root_dir, label)

                -- Check if this lsp is filtered by filetype, and if so make sure that
                -- this buffer's filetype matches
                local filetypes = config.filetypes or {}
                local buf_ft = vim.api.nvim_buf_get_option(buf, 'filetype')
                if vim.tbl_isempty(filetypes) or vim.tbl_contains(filetypes, buf_ft) then
                    log.fmt_trace('File %s of type %s applies to %s', path, buf_ft, label)

                    -- Start the client if it doesn't exist
                    if lsp.__clients[label] == nil then
                        -- Wrap the exit so we can clear our id tracker
                        local on_exit = function(code, signal, client_id)
                            lsp.__clients[label] = nil

                            if code ~= 0 then
                                log.fmt_error('Client terminated: %s', vim.lsp.client_errors[client_id])
                            end

                            if type(config.on_exit) == 'function' then
                                config.on_exit(code, signal, client_id)
                            end
                        end

                        -- Support lsp-specific opts
                        log.fmt_debug('Starting LSP %s', label)
                        local opts = config.opts or {}
                        local id = lsp_start_client(u.merge(config, {on_exit = on_exit}), opts)
                        lsp.__clients[label] = id
                    end

                    -- Attach to our buffer if it isn't already
                    local client_id = lsp.__clients[label]
                    if not vim.lsp.buf_is_attached(client_id) then
                        log.fmt_debug('Attaching to buf %s for LSP %s', buf, label)
                        vim.lsp.buf_attach_client(buf, client_id)
                    end
                end
            end
        end
    end
end

return lsp
