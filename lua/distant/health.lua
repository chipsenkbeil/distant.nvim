local plugin = require('distant')

local M = {}

-- "report_" prefix has been deprecated, use the recommended replacements if they exist.
local start = vim.health.start or vim.health.report_start
local ok = vim.health.ok or vim.health.report_ok
local warn = vim.health.warn or vim.health.report_warn
local error = vim.health.error or vim.health.report_error

--- Primary health entrypoint for distant.
function M.check()
    start('distant.nvim')
    M.__check_installed()
    M.__check_version()
end

--- Check that we have the distant CLI installed for our plugin.
--- @private
function M.__check_installed()
    local path = plugin:cli_path()
    if vim.fn.executable(path) == 1 then
        ok('distant installed')
    else
        error('distant not installed')
    end
end

--- Check that our version of the distant CLI is compatible with the plugin.
--- @private
function M.__check_version()
    local version = plugin:cli():version()
    local version_ok = version and version:can_upgrade_from(plugin.version.cli.min, {
        allow_unstable_upgrade = plugin.settings.client.allow_unstable
    })
    if version and version_ok then
        ok(
            'distant version ' .. tostring(version) ..
            ' meets minimum requirement of ' .. tostring(plugin.version.cli.min)
        )
    elseif version and not version_ok then
        error(
            'distant version ' .. tostring(version) ..
            ' incompatible with requirement of ' .. tostring(plugin.version.cli.min)
        )
    else
        error('unable to retrieve distant CLI version')
    end
end

return M
