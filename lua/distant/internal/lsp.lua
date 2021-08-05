local g = require('distant.internal.globals')
local u = require('distant.internal.utils')

local lsp = {}

--- Wraps `vim.lsp.start_client`, injecting necessary details to run the
--- LSP binary on the connected remote machine while acquiring and
--- visualizing results on the local machine
---
--- @param config table The configuration to use with the LSP client,
---        mirring that of `vim.lsp.start_client`
--- @return number #The id of the created client
lsp.start_client = function(config)
    assert(type(config) == 'table', 'config must be a table')
    assert(config.cmd, 'cmd is required')
    assert(config.root_dir, 'root_dir is required')

    print('session')
    local session = assert(g.session(), 'Session not yet established! Launch first!')

    -- The command needs to be wrapped with a prefix that is our distant binary
    -- as we are running the actual lsp server remotely
    print('cmd')
    local cmd = vim.list_extend(
        {
            g.settings.binary_name,
            'action',
            '-m', 'shell',
            '--session', 'environment',
            '-vvv',
            '--log-file', '/tmp/lsp.distant.log',
            'proc-run', 
            '--',
        },
        config.cmd
    )

    -- Provide our credentials as part of the environment so our proxy
    -- knows who to talk to and has access to do so
    print('cmd_env')
    local cmd_env = u.merge(config.cmd_env or {}, {
        ['DISTANT_HOST'] = session.host;
        ['DISTANT_PORT'] = session.port;
        ['DISTANT_AUTH_KEY'] = session.auth_key;
    })

    -- TODO: Followed this based on nvim-lspconfig, but don't yet understand
    --       the workspace configuration override
    print('capabilities')
    local capabilities = config.capabilities or vim.lsp.protocol.make_client_capabilities();
    capabilities = u.merge(capabilities, {
        workspace = {
          configuration = true,
        }
    })

    print('start_client')
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
