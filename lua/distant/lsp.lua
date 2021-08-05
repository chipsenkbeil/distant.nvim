local g = require('distant.internal.globals')
local u = require('distant.internal.utils')

local lsp = {}

lsp.start_client = function(config)
    assert(type(config) == 'table', 'config must be a table')
    assert(config.cmd, 'cmd is required')
    assert(config.root_dir, 'root_dir is required')

    return vim.lsp.start_client(u.merge(config, {
        cmd = vim.list_extend(
            {
                g.settings.binary_name,
                'action',
                '-m', 'shell',
                '--session', 'environment',
                '-vvv',
                '--log-file', '/tmp/lsp.distant.log',
                'proc-run', '--'
            },
            config.cmd
        );
    }))
end

lsp.test = function()
    -- vim.cmd([[ DistantLaunch localhost ]])
    vim.cmd([[ DistantOpen /Users/senkwich/projects/memtable-rs/memtable-core/src/list.rs ]])

    local session = assert(g.session(), 'missing session')

    local client_id = lsp.start_client({
        cmd = {'/Users/senkwich/.local/bin/rust-analyzer'};
        root_dir = '/Users/senkwich/projects/memtable-rs';
        cmd_cwd = '/Users/senkwich/projects/memtable-rs';
        cmd_env = {
            ['DISTANT_HOST'] = session.host;
            ['DISTANT_PORT'] = session.port;
            ['DISTANT_AUTH_KEY'] = session.auth_key;
        };
    })

    print('lsp log: ' .. vim.lsp.get_log_path())

    vim.lsp.buf_attach_client(0, client_id)
end

return lsp
