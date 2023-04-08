local config = {}

config.timeout = tonumber(os.getenv('DISTANT_TIMEOUT')) or 1000
config.timeout_interval = tonumber(os.getenv('DISTANT_TIMEOUT_INTERVAL')) or 200

-- Clear out any empty config options
for k, v in pairs(config) do
    if v == '' then
        config[k] = nil
    end
end

return config
