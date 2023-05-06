local M = {
    timeout          = tonumber(os.getenv('DISTANT_TIMEOUT')) or 1000,
    timeout_interval = tonumber(os.getenv('DISTANT_TIMEOUT_INTERVAL')) or 200,
}

-- Clear out any empty config options
for k, v in pairs(M) do
    if v == '' then
        M[k] = nil
    end
end

return M
