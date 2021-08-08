local s = require('distant.internal.state')
local u = require('distant.internal.utils')

local lsp = {
    -- Houses LSP clients in the form of
    --
    -- {
    --     id = "...",
    --     root_dir = "...",
    -- }
    clients = {},
}

--- Wraps `vim.lsp.start_client`, injecting necessary details to run the
--- LSP binary on the connected remote machine while acquiring and
--- visualizing results on the local machine
---
--- @param config table The configuration to use with the LSP client,
---        mirring that of `vim.lsp.start_client`
--- @param opts table Additional options to use for the distant binary
---        acting as a proxy such as `log_file` or `verbose`
--- @return number #The id of the created client
lsp.start_client = function(config, opts)
    assert(type(config) == 'table', 'config must be a table')
    assert(config.cmd, 'cmd is required')
    assert(config.root_dir, 'root_dir is required')
    opts = opts or {}

    local session = assert(s.session(), 'Session not yet established! Launch first!')

    -- Build our extra arguments for the distant binary
    local args = u.build_arg_str(opts, {'verbose'})
    if type(opts.verbose) == 'number' and opts.verbose > 0 then
        args = vim.trim(args .. ' -' .. string.rep('v', opts.verbose))
    end
    args = vim.split(args, ' ', true)

    -- The command needs to be wrapped with a prefix that is our distant binary
    -- as we are running the actual lsp server remotely
    local cmd = {
        s.settings.binary_name,
        'action',
        '--mode', 'shell',
        '--session', 'environment',
    }
    cmd = vim.list_extend(cmd, args)
    cmd = vim.list_extend(cmd, {'proc-run', '--'})
    cmd = vim.list_extend(cmd, config.cmd)

    -- Provide our credentials as part of the environment so our proxy
    -- knows who to talk to and has access to do so
    local cmd_env = u.merge(config.cmd_env or {}, {
        ['DISTANT_HOST'] = session.host;
        ['DISTANT_PORT'] = session.port;
        ['DISTANT_AUTH_KEY'] = session.auth_key;
    })

    -- TODO: Followed this based on nvim-lspconfig, but don't yet understand
    --       the workspace configuration override
    local capabilities = config.capabilities or vim.lsp.protocol.make_client_capabilities();
    capabilities = u.merge(capabilities, {
        workspace = {
          configuration = true,
        }
    })

    return vim.lsp.start_client(u.merge(config, {
        cmd = cmd;
        cmd_env = cmd_env;
        capabilities = capabilities;
    }))
end

lsp.test = function()
    -- vim.cmd([[ DistantLaunch localhost ]])
    vim.cmd([[ DistantOpen /Users/senkwich/projects/memtable-rs/memtable-core/src/list.rs ]])

    local client_id = lsp.start_client({
        cmd = {'/Users/senkwich/.local/bin/rust-analyzer'};
        root_dir = '/Users/senkwich/projects/memtable-rs';
        cmd_cwd = '/Users/senkwich/projects/memtable-rs';
    })

    print('lsp log: ' .. vim.lsp.get_log_path())

    vim.lsp.buf_attach_client(0, client_id)
end

return lsp
