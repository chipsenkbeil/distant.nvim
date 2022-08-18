local config = {}

-- Should be the root of our project if tests are run via `make test`
config.cwd = os.getenv('PWD') or io.popen('cd'):read()
config.root_dir = os.getenv('DISTANT_ROOT_DIR') or config.cwd
config.bin = os.getenv('DISTANT_BIN')

config.host = os.getenv('DISTANT_HOST') or 'localhost'
config.port = tonumber(os.getenv('DISTANT_PORT')) or 22
config.identity_file = os.getenv('DISTANT_IDENTITY_FILE')
config.user = assert(os.getenv('DISTANT_USER'), 'DISTANT_USER not set')
assert(config.user ~= '', 'DISTANT_USER cannot be empty')
config.password = os.getenv('DISTANT_PASSWORD')
config.mode = os.getenv('DISTANT_MODE')
config.ssh_backend = os.getenv('DISTANT_SSH_BACKEND')

config.timeout = tonumber(os.getenv('DISTANT_TIMEOUT')) or (1000 * 30)
config.timeout_interval = tonumber(os.getenv('DISTANT_TIMEOUT_INTERVAL')) or 200

-- Clear out any empty config options
for k, v in pairs(config) do
    if v == '' then
        config[k] = nil
    end
end

return config
