local log = require('distant.log')
local s = require('distant.settings')
local u = require('distant.utils')
local v = require('distant.vars')

local state = {}

-- Inner data that is not directly exposed
local inner = {
    client = nil;
    data = {};
    session = nil;
    lsp_clients = {};
}

-------------------------------------------------------------------------------
-- SETTINGS DEFINITION & OPERATIONS
-------------------------------------------------------------------------------

--- Loads into state the settings appropriate for the remote machine with
--- the given label
state.load_settings = function(label)
    state.settings = s.for_label(label)
end

-- Set default settings so we don't get nil access errors even when no launch
-- call has been made yet
state.settings = s.default()

-------------------------------------------------------------------------------
-- LSP OPERATIONS
-------------------------------------------------------------------------------

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

    local session = assert(state.session(), 'Session not yet established! Launch first!')

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

    -- Provide our credentials as part of the initialization options so our proxy
    -- knows who to talk to and has access to do so
    local init_options = u.merge(config.init_options or {}, {
        ['distant'] = {
            ['host'] = session.host;
            ['port'] = session.port;
            ['key'] = session.key;
        }
    })

    -- TODO: Followed this based on nvim-lspconfig, but don't yet understand
    --       the workspace configuration override
    local capabilities = config.capabilities or vim.lsp.protocol.make_client_capabilities();
    capabilities = u.merge(capabilities, {
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

    -- Override the config's cmd, init_options, and capabilities
    -- as we take those existing config fields and alter them to work on
    -- a remote machine
    local lsp_config = u.merge(
        config,
        {
            before_init = before_init;
            cmd = cmd;
            capabilities = capabilities;
            init_options = init_options;

            -- Must zero these out to ensure that we pass validation
            -- TODO: Support Windows local machine
            root_dir = '/';
            workspace_folders = nil;
        }
    )
    return vim.lsp.start_client(lsp_config)
end

--- Contains operations to apply against LSP instances on remote machines
state.lsp = {}

--- Connects relevant LSP clients to the provided buffer, optionally
--- starting clients if needed
--- @param buf number Handle of the buffer where clients will attach
state.lsp.connect = function(buf)
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
                    if inner.lsp_clients[label] == nil then
                        -- Wrap the exit so we can clear our id tracker
                        local on_exit = function(code, signal, client_id)
                            inner.lsp_clients[label] = nil

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
                        inner.lsp_clients[label] = id
                    end

                    -- Attach to our buffer if it isn't already
                    local client_id = inner.lsp_clients[label]
                    if not vim.lsp.buf_is_attached(client_id) then
                        log.fmt_debug('Attaching to buf %s for LSP %s', buf, label)
                        vim.lsp.buf_attach_client(buf, client_id)
                    end
                end
            end
        end
    end
end

-------------------------------------------------------------------------------
-- DATA OPERATIONS
-------------------------------------------------------------------------------

--- Contains operations to apply against a global collection of functions
state.data = {}

--- Inserts data into the global storage, returning an id for future reference
---
--- @param data any The data to store
--- @param prefix? string Optional prefix to add to the id created for the data
--- @return string #A unique id associated with the data
state.data.insert = function(data, prefix)
    prefix = prefix or 'data_'
    local id = prefix .. u.next_id()
    inner.data[id] = data
    return id
end

--- Removes the data with the specified id
---
--- @param id string The id associated with the data
--- @return any? #The removed data, if any
state.data.remove = function(id)
    return state.data.set(id, nil)
end

--- Updates data by its id
---
--- @param id string The id associated with the data
--- @param value any The new value for the data
--- @return any? #The old value of the data, if any
state.data.set = function(id, value)
    local data = inner.data[id]
    inner.data[id] = value
    return data
end

--- Retrieves data by its id
---
--- @param id string The id associated with the data
--- @return any? #The data if found
state.data.get = function(id)
    return inner.data[id]
end

--- Checks whether data with the given id exists
---
--- @param id string The id associated with the data
--- @return boolean #True if it exists, otherwise false
state.data.has = function(id)
    return inner.data[id] ~= nil
end

--- Retrieves a key mapping around some data by the data's id,
--- assuming that the data will be a function that can be invoked
---
--- @param id number The id associated with the data
--- @param args? string[] #Arguments to feed directly to the data as a function
--- @return string #The mapping that would invoke the data with the given id
state.data.get_as_key_mapping = function(id, args)
    args = table.concat(args or {}, ',')
    return 'lua require("distant.state").data.get("' .. id .. '")(' .. args .. ')'
end

-------------------------------------------------------------------------------
-- SESSION OPERATIONS
-------------------------------------------------------------------------------

--- Sets the globally-available session
--- @param session table|nil the session in the form of {host, port, key}
state.set_session = function(session)
    inner.session = session
end

--- Returns the current session, or nil if unavailable
--- @return table|nil #the session in the form of {host, port, key}
state.session = function()
    return inner.session
end

return state
