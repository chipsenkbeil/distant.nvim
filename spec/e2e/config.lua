-- Should be the root of our project if tests are run via `make test`
--- @type string
local cwd = os.getenv('PWD') or io.popen('cd'):read()

local M = {
    cwd              = cwd,
    lsp_cmd          = os.getenv('DISTANT_LSP_CMD') or 'lua-language-server',
    root_dir         = os.getenv('DISTANT_ROOT_DIR') or cwd,
    bin              = os.getenv('DISTANT_BIN'),
    host             = os.getenv('DISTANT_HOST') or 'localhost',
    port             = tonumber(os.getenv('DISTANT_PORT')) or 22,
    identity_file    = os.getenv('DISTANT_IDENTITY_FILE'),
    user             = assert(os.getenv('DISTANT_USER'), 'DISTANT_USER not set'),
    password         = os.getenv('DISTANT_PASSWORD'),
    mode             = os.getenv('DISTANT_MODE'),
    ssh_backend      = os.getenv('DISTANT_SSH_BACKEND'),
    timeout          = tonumber(os.getenv('DISTANT_TIMEOUT')) or (1000 * 30),
    timeout_interval = tonumber(os.getenv('DISTANT_TIMEOUT_INTERVAL')) or 200,
}

assert(M.user ~= '', 'DISTANT_USER cannot be empty')

-- Clear out any empty config options
for k, v in pairs(M) do
    if v == '' then
        M[k] = nil
    end
end

return M
