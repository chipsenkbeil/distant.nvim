local Api               = require('distant-core.api')
local builder           = require('distant-core.builder')
local Job               = require('distant-core.job')
local log               = require('distant-core.log')
local utils             = require('distant-core.utils')

local callable          = utils.callable
local validate_callable = utils.validate_callable

--- Represents a distant.core.client
--- @class distant.core.Client
--- @field id distant.core.manager.ConnectionId # id tied to the client's connection
--- @field api distant.core.Api
--- @field private config {binary:string, network:distant.core.client.Network}
--- @field private __state distant.core.client.State
local M                 = {}
M.__index               = M

--- @class distant.core.client.Network
--- @field connection distant.core.manager.ConnectionId #id of the connection tied to the client
--- @field unix_socket? string #path to the unix socket of the manager
--- @field windows_pipe? string #name of the windows pipe of the manager

--- @class distant.core.client.State
--- @field cache {system_info?:distant.core.api.SystemInfoPayload}
--- @field lsp {clients:table<string, number>} Mapping of label -> client id

--- Creates a new instance of a distant.core.client
--- @param opts {id:distant.core.manager.ConnectionId, binary:string, network:distant.core.client.Network}
--- @return distant.core.Client
function M:new(opts)
    opts = opts or {}

    local instance = {}
    setmetatable(instance, M)
    instance.id = assert(opts.id, 'Client missing id')
    instance.config = {
        binary = opts.binary,
        network = vim.tbl_deep_extend('force', vim.deepcopy(opts.network) or {}, {
            connection = instance.id
        }),
    }
    assert(instance.config.binary, 'Client missing binary')
    assert(instance.config.network, 'Client missing network')
    assert(instance.id == instance.config.network.connection, 'Client id and connection are different')

    instance.api = Api:new({
        binary = instance.config.binary,
        network = instance.config.network,
    })

    instance.__state = {
        cache = {},
        lsp = {
            clients = {},
        },
    }

    return instance
end

--- Returns a copy of this client's network settings.
--- @return distant.core.client.Network
function M:network()
    return vim.deepcopy(self.config.network)
end

--- Loads the system information for the connected server. This will be cached
--- for future requests. Specifying `reload` as true will result in a fresh
--- request to the server for this information.
---
--- @alias distant.core.client.CachedSystemInfoOpts {reload?:boolean, timeout?:number, interval?:number}
--- @param opts distant.core.client.CachedSystemInfoOpts
--- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.SystemInfoPayload)
--- @return distant.core.api.Error|nil, distant.core.api.SystemInfoPayload|nil
function M:cached_system_info(opts, cb)
    vim.validate({
        opts = { opts, 'table' },
        cb = { cb, validate_callable({ optional = true }) },
    })

    if not opts.reload and self.__state.cache.system_info ~= nil then
        if cb then
            cb(nil, self.__state.cache.system_info)
            return
        else
            return nil, self.__state.cache.system_info
        end
    end

    if cb then
        self.api:system_info({
            timeout = opts.timeout,
            interval = opts.interval,
        }, function(err, payload)
            if err then
                cb(err, nil)
            else
                self.__state.cache.system_info = payload
                cb(nil, payload)
            end
        end)
    else
        local err, payload = self.api:system_info({
            timeout = opts.timeout,
            interval = opts.interval,
        })
        if err then
            return err, nil
        else
            self.__state.cache.system_info = payload
            return nil, payload
        end
    end
end

--- Connects relevant LSP clients to the provided buffer, optionally starting clients if needed.
---
--- * `bufnr` - buffer handle to attach LSP clients
--- * `path` - path on remote machine of buffer, used to determine which settings to apply
--- * `scheme` - used to change the scheme used in the editor to `file` for the language server
---              and vice versa. If not provided, defaults to `distant`.
--- * `settings` - collection of LSP settings to apply
---
--- @param opts {bufnr:number, path:string, scheme?:string, settings:distant.plugin.settings.server.LspSettings}
--- @return number[] client_ids All ids of the LSP clients (if any) established with the buffer
function M:connect_lsp_clients(opts)
    log.fmt_trace('client.connect_lsp_clients(%s)', opts)
    local client_ids = {}
    local path = opts.path
    log.fmt_trace('Seeking LSP clients that cover path = %s', path)

    --- @generic T
    --- @param array T[]
    --- @param f fun(x:T):boolean
    --- @return T|nil
    local function find(array, f)
        for _, v in ipairs(array) do
            if f(v) then
                return v
            end
        end
    end

    -- Only perform a connection if we have connected and have a remote path.
    --
    -- If that's the case, we want to ensure that we only start an LSP client
    -- once per session as well as attach it to a buffer only once
    -- (not on enter).
    if path ~= nil then
        --- @param prefix string
        --- @return boolean
        local function path_starts_with(prefix)
            return vim.startswith(path, prefix)
        end

        for label, config in pairs(opts.settings) do
            --- @type string|nil
            local root_dir

            -- Look up the root directory following this logic:
            --
            -- 1. If config.root_dir is a string, check if it contains our path
            -- 2. If config.root_dir is a list of strings, check if any contain our path
            -- 3. If config.root_dir is a function, feed it our path and use whatever path is returned
            local config_root_dir = config.root_dir
            if type(config_root_dir) == 'string' and path_starts_with(config_root_dir) then
                root_dir = config_root_dir
            elseif type(config_root_dir) == 'table' then
                root_dir = find(config_root_dir, path_starts_with)
            elseif config_root_dir and callable(config_root_dir) then
                root_dir = config_root_dir(path, opts.bufnr)
            end

            --- Performs actual process of attaching a client to a buffer using the `root_dir`.
            --- @param root_dir string
            local function do_connect_client(root_dir)
                assert(type(root_dir) == 'string', ('Invalid root dir: %s'):format(vim.inspect(root_dir)))
                log.fmt_trace('File %s is within %s of %s', path, root_dir, label)

                -- Check if this lsp is filtered by filetype, and if so make sure that
                -- this buffer's filetype matches
                local filetypes = config.filetypes or {}
                local buf_ft = vim.api.nvim_buf_get_option(opts.bufnr, 'filetype')
                if vim.tbl_isempty(filetypes) or vim.tbl_contains(filetypes, buf_ft) then
                    log.fmt_trace('File %s of type %s applies to %s', path, buf_ft, label)

                    -- Start the client if it doesn't exist
                    if self.__state.lsp.clients[label] == nil then
                        -- Wrap the exit so we can clear our id tracker
                        local on_exit = function(code, signal, client_id)
                            self.__state.lsp.clients[label] = nil

                            if code ~= 0 then
                                log.fmt_error('Client terminated: %s', vim.lsp.client_errors[client_id])
                            end

                            if config.on_exit and callable(config.on_exit) then
                                config.on_exit(code, signal, client_id)
                            end
                        end

                        local cmd = self:wrap({ lsp = config.cmd, scheme = opts.scheme })

                        config = vim.tbl_deep_extend('force', config, {
                            cmd = cmd,
                            on_exit = on_exit,
                            root_dir = root_dir,
                        })

                        -- Start LSP server using the provided configuration, replacing the
                        -- command with the distant-wrapped verison and shadowing the
                        -- on_exit command if provided
                        log.fmt_debug('Starting LSP %s: %s', label, config)
                        local id = vim.lsp.start_client(config)
                        self.__state.lsp.clients[label] = id
                    end

                    -- Attach to our buffer if it isn't already
                    local client_id = self.__state.lsp.clients[label]
                    if not vim.lsp.buf_is_attached(opts.bufnr, client_id) then
                        log.fmt_debug('Attaching to buf %s for LSP %s', opts.bufnr, label)
                        vim.lsp.buf_attach_client(opts.bufnr, client_id)
                    end
                    if type(client_id) == 'number' then
                        table.insert(client_ids, client_id)
                    end
                end
            end

            -- Only apply client with a root directory that contains this file. If the root_dir
            -- was set to a function, we assume that we are running async and instead provide
            -- a callback function that will perform the connection.
            if type(root_dir) == 'string' then
                do_connect_client(root_dir)
            elseif root_dir ~= nil and callable(root_dir) then
                vim.schedule(function()
                    root_dir(do_connect_client)
                end)
            end
        end
    end

    return client_ids
end

--- Spawns a shell connected to the buffer with handle `bufnr`.
---
--- * `bufnr` specifies the buffer to use. If -1, will create a new buffer.
--- * `winnr` specifies the window to use. Default is current window.
--- * `cmd` is the optional command to use instead of the server's default shell.
--- * `cwd` is the optional current working directory to set for the shell when spawning it.
--- * `env` is the optional map of environment variable values to supply to the shell.
---
--- Will fail with an error if the shell fails to spawn.
---
--- @param opts {bufnr:number, winnr?:number, cmd?:string|string[], cwd?:string, env?:table<string, string>}
--- @return number job-id, number bufnr
function M:spawn_shell(opts)
    -- Get or create the buffer we will be using with this terminal,
    -- ensure it is no longer modifiable, switch to it, and then
    -- spawn the remote shell
    local bufnr = opts.bufnr
    if bufnr < 0 then
        bufnr = vim.api.nvim_create_buf(true, false)
        assert(bufnr ~= 0, 'Failed to create buffer for remote shell')
    end
    vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)
    vim.api.nvim_win_set_buf(opts.winnr or 0, bufnr)

    local cmd = self:wrap({ shell = opts.cmd or true, cwd = opts.cwd, env = opts.env })

    --- `termopen` returns same as `job_start`, which is a number where >0 is the id.
    --- @type number
    --- @diagnostic disable-next-line:assign-type-mismatch
    local job_id = vim.fn.termopen(cmd)

    if job_id == 0 then
        error('Invalid arguments: ' .. vim.inspect(cmd))
    elseif job_id == -1 then
        error(self.config.binary .. ' is not executable')
    end

    return job_id, bufnr
end

--- @class distant.core.client.SpawnWrapOpts
--- @field cmd string|string[]
--- @field cwd? string
--- @field env? table<string,string>
--- @field shell? string|string[]|true

--- Spawns a `cmd` created using the `wrap` method,
--- buffering stdout and stderr as it is received.
---
--- @param opts distant.core.client.SpawnWrapOpts
--- @param cb? fun(err?:string, exit_status:distant.core.job.ExitStatus)
--- @return distant.core.Job
function M:spawn_wrap(opts, cb)
    vim.validate({
        opts = { opts, 'table' },
        cb = { cb, validate_callable({ optional = true }) },
    })

    local cmd = self:wrap({
        cmd = opts.cmd,
        cwd = opts.cwd,
        env = opts.env,
        shell = opts.shell,
    })

    local job = Job:new({ buffer_stdout = true, buffer_stderr = true })

    -- Start the job, passing in our optional callback when it's done,
    -- and only explicitly error if we do not have a callback to
    -- report the error
    local ok = job:start({ cmd = cmd }, cb)
    if not ok and not cb then
        error('Failed to spawn cmd: ' .. vim.inspect(cmd))
    end

    return job
end

--- @class distant.core.client.WrapOpts
--- @field cmd? string|string[]
--- @field lsp? string|string[]
--- @field shell? string|string[]|true
--- @field cwd? string
--- @field env? table<string,string>
--- @field scheme? string

--- Wraps cmd, lsp, or shell to be invoked via distant for this client. Returns
--- a string if the input is a string, or a list if the input
--- is a list.
---
--- If both `cmd` and `shell` are provided, then `spawn` is invoked with
--- the command and `shell` is used as the `--shell <shell>` parameter.
---
--- @param opts distant.core.client.WrapOpts
--- @return string|string[]
function M:wrap(opts)
    opts = opts or {}
    opts.type = opts.type or 'string'

    local has_cmd = opts.cmd ~= nil
    local has_lsp = opts.lsp ~= nil
    local has_shell = opts.shell ~= nil

    -- We require exactly one of "cmd", "lsp", or "shell" UNLESS
    -- we are given "cmd" and "shell", in which case "shell" is used
    -- as the `--shell <shell>` parameter for the spawn command
    if not has_cmd and not has_lsp and not has_shell then
        error('Missing one of ["cmd", "lsp", "shell"] argument')
    elseif (has_cmd and has_lsp) or (has_lsp and has_shell) then
        error('Can only have exactly one of ["cmd", "lsp", "shell"] argument')
    end

    --- @type string[]
    local result = {}

    if has_cmd then
        -- Prefer `--cmd '...'` over `-- ...`
        local cmd = builder.spawn(opts.cmd, true)
            :set_connection(tostring(self.id))
        if type(opts.cwd) == 'string' then
            cmd = cmd:set_current_dir(opts.cwd)
        end
        if opts.env then
            cmd = cmd:set_environment(opts.env)
        end

        -- If we were given a shell, then set it as a parameter here
        local shell = opts.shell
        if shell then
            if type(shell) == 'table' then
                shell = table.concat(shell, ' ')
            end
            cmd = cmd:set_shell(shell)
        end

        result = cmd:set_from_tbl(self.config.network):as_list()
        table.insert(result, 1, self.config.binary)
    elseif has_lsp then
        local cmd = builder.spawn(opts.lsp)
            :set_connection(tostring(self.id))
            :set_lsp(opts.scheme or true)
        if opts.cwd then
            cmd = cmd:set_current_dir(opts.cwd)
        end
        if opts.env then
            cmd = cmd:set_environment(opts.env)
        end

        result = cmd:set_from_tbl(self.config.network):as_list()
        table.insert(result, 1, self.config.binary)
    elseif has_shell then
        -- Build with no explicit cmd by default (use $SHELL)
        local cmd = builder.shell()
            :set_connection(tostring(self.id))

        -- If provided a specific shell, use that instead of default
        if type(opts.shell) == 'string' or type(opts.shell) == 'table' then
            -- NOTE: We know that we have an explicit shell arg, but our
            --       lua language server still things `true` is an option,
            --       so we disable the error on the following line!
            --- @diagnostic disable-next-line
            cmd = builder.shell(opts.shell)
        end

        if opts.cwd then
            cmd = cmd:set_current_dir(opts.cwd)
        end
        if opts.env then
            cmd = cmd:set_environment(opts.env)
        end

        result = cmd:set_from_tbl(self.config.network):as_list()
        table.insert(result, 1, self.config.binary)
    end

    -- If input was string, output will be a string
    if type(opts.cmd) == 'string' or type(opts.lsp) == 'string' or type(opts.shell) == 'string' then
        return table.concat(result, ' ')
    else
        return result
    end
end

return M
