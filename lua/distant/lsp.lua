local log = require('distant.log')
local fn = require('distant.fn')
local state = require('distant.state')
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
--- @return number #The id of the created client
lsp.start_client = function(config)
    vim.validate({config = {config, 'table'}})
    log.fmt_trace('distant.lsp.start_client(%s)', config)

    local capabilities = config.capabilities or vim.lsp.protocol.make_client_capabilities();
    capabilities = vim.tbl_deep_extend('keep', {
        workspace = {
          configuration = true,
        }
    }, capabilities)

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

    -- Override the capabilities, root_dir, and workspace folders to work with
    -- pur remote LSP server
    local lsp_config = vim.tbl_deep_extend(
        'keep',
        {
            before_init = before_init;
            capabilities = capabilities;

            -- Must zero these out to ensure that we pass validation
            -- TODO: Support Windows local machine
            root_dir = '/';
            workspace_folders = nil;
        },
        config
    )

    -- NOTE: Need to overwrite uv.spawn (aka vim.loop.spawn) temporarily
    local uv_spawn = vim.loop.spawn
    vim.loop.spawn = function(cmd, spawn_params, on_exit)
        vim.validate({
            cmd = {cmd, 'string'},
            ['spawn_params.args'] = {spawn_params.args, 'table'},
            ['spawn_params.stdio'] = {spawn_params.stdio, 'table'},
            on_exit = {on_exit, 'function'},
        })

        -- spawn_params.args = {stdin, stdout, stderr}
        local stdin = spawn_params.stdio[1]
        local stdout = spawn_params.stdio[2]
        local stderr = spawn_params.stdio[3]

        local err, proc = fn.spawn_lsp({
            cmd = cmd,
            args = spawn_params.args or {},
        })

        if err then
            return nil, err
        end

        -- Configure the pipes for the given process
        stdin.__set(proc, 'stdin')
        stdout.__set(proc, 'stdout')
        stderr.__set(proc, 'stderr')

        -- Spawn polling check for process to complete
        local inner_on_exit
        inner_on_exit = function()
            proc.status(function(err, status)
                if err then
                    error(tostring(err))
                end

                -- If we get a status, then we're done
                -- on_exit(code, signal used to terminate)
                if status then
                    local code = status.exit_code or (status.success and 0 or 1)
                    on_exit(code)

                -- Otherwise, queue up another check
                else
                    vim.defer_fn(inner_on_exit, state.settings.poll_interval)
                end
            end)
        end
        vim.schedule(inner_on_exit)

        local handle = {
            -- returns bool if closing or closed
            -- luv has note that only used between init and before close cb
            is_closing = function()
                return not proc.is_active()
            end,

            -- cb() (optional) when done
            -- returns nothing
            close = function(cb)
                -- Always try a kill and ignore results
                proc.kill(function()
                    -- Make sure the process stops its tasks
                    proc.abort(function()
                        cb()
                    end)
                end)
            end,

            -- Only ever sends 15, which is sigterm
            -- returns 0 or fail
            kill = function(signum)
                local success, err = pcall(proc.kill, proc)
                if success then
                    return 0
                else
                    error(string.format('kill(%s): %s', signum, tostring(err)))
                end
            end,
        }
        return handle, proc.id
    end

    -- NOTE: Need to overwrite uv.new_pipe (aka vim.loop.new_pipe) temporarily
    local uv_new_pipe = vim.loop.new_pipe
    vim.loop.new_pipe = function()
        local pipe_proc, pipe_ty
        return {
            --- Private function used to set the pipe from within the uv.spawn wrapper
            --- @param proc userdata Process associated with the pipe
            --- @param ty string Type of pipe (stdin|stdout|stderr)
            __set = function(proc, ty)
                pipe_proc = proc
                pipe_ty = ty
            end,

            -- cb() (optional) when done
            -- returns nothing
            close = function(cb)
                pipe_proc = nil
                pipe_ty = nil
                if type(cb) == 'function' then
                    cb()
                end
            end,

            -- read_start(self, cb)
            -- cb(err = string|nil, data = string|nil)
            -- returns 0 or fail
            read_start = function(_, cb)
                assert(pipe_proc, 'Pipe not configured! Must be passed to uv.spawn(...)')

                local read_loop
                if pipe_ty == 'stdout' then
                    read_loop = function()
                        -- Signals closing of pipe
                        if pipe_proc == nil then
                            return
                        end

                        pipe_proc.read_stdout({}, function(...)
                            cb(...)

                            -- If we still have pipe (because it can become nil) and it is active
                            if pipe_proc and pipe_proc.is_active() then
                                vim.defer_fn(read_loop, state.settings.poll_interval)
                            end
                        end)
                    end
                    vim.schedule(read_loop)
                    return 0
                elseif pipe_ty == 'stderr' then
                    read_loop = function()
                        -- Signals closing of pipe
                        if pipe_proc == nil then
                            return
                        end

                        pipe_proc.read_stderr({}, function(...)
                            cb(...)

                            -- If we still have pipe (because it can become nil) and it is active
                            if pipe_proc and pipe_proc.is_active() then
                                vim.defer_fn(read_loop, state.settings.poll_interval)
                            end
                        end)
                    end
                    vim.schedule(read_loop)
                    return 0
                else
                    error('pipe is not stdout or stderr')
                end
            end,

            -- read_start(self, data, cb)
            -- data = string, cb = function() (optional) when done
            -- returns uv_write_t (unused) or fail
            write = function(_, data, cb)
                assert(pipe_proc, 'Pipe not configured! Must be passed to uv.spawn(...)')

                if pipe_ty ~= 'stdin' then
                    error('pipe is not stdin')
                end
                return pipe_proc.write_stdin(data, function()
                    if type(cb) == 'function' then
                        cb()
                    end
                end)
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
    log.fmt_trace('distant.lsp.connect(%s)', buf)
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
                        local id = lsp.start_client(vim.tbl_deep_extend('keep', {on_exit = on_exit}, config))
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
