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
    if plugin:cli():is_executable() then
        ok('distant installed')
    else
        error('distant not installed')
    end
end

--- Check that our version of the distant CLI is compatible with the plugin.
--- @private
function M.__check_version()
    local required_version = plugin.version.cli.min

    local version = plugin:cli():version()
    local version_ok = version and version:compatible(required_version)
    if version and version_ok then
        ok(('distant version %s meets minimum requirement of %s'):format(
            tostring(version), tostring(required_version)
        ))
    elseif version and not version_ok then
        error(('distant version %s incompatible with minimum requirement of %s'):format(
            tostring(version), tostring(required_version)
        ))
    else
        error('unable to retrieve distant CLI version')
    end
end

return M
