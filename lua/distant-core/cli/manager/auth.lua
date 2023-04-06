local AuthHandler = require('distant-core.cli.auth')
local log = require('distant-core.log')
local utils = require('distant-core.utils')

local M = {}

--- Spawn a command that does some authentication and eventually returns an id upon success
--- @param opts {cmd:string|string[], auth:AuthHandler|nil}
--- @param cb fun(err:string|nil, connection:string|nil)
--- @return JobHandle
function M.spawn(opts, cb)
    opts = opts or {}
    assert(opts.cmd, 'missing cmd')

    local handle, connection, error_lines
    connection = nil
    error_lines = {}

    -- Use provided auth handler, defaulting to a fresh instance if none provided
    --- @type AuthHandler
    local auth = opts.auth or AuthHandler:new()

    handle = utils.job_start(opts.cmd, {
        on_success = function()
            if not vim.tbl_isempty(error_lines) then
                log.error(table.concat(error_lines, '\n'))
            end

            if not connection then
                return cb('Completed, but missing connection')
            else
                return cb(nil, connection)
            end
        end,
        on_failure = function(code)
            local error_msg = '???'
            if not vim.tbl_isempty(error_lines) then
                error_msg = table.concat(error_lines, '\n')
            end

            error_msg = 'Failed (' .. tostring(code) .. '): ' .. error_msg
            return cb(error_msg)
        end,
        on_stdout_line = function(line)
            if line ~= nil and line ~= "" then
                local msg = vim.fn.json_decode(line)
                if auth:is_auth_msg(msg) then
                    --- @diagnostic disable-next-line:redefined-local
                    auth:handle_msg(msg, function(msg)
                        handle.write(utils.compress(vim.fn.json_encode(msg)) .. '\n')
                    end)
                elseif msg.type == 'launched' or msg.type == 'connected' then
                    -- NOTE: Lua 5.1 cannot handle an unsigned 64-bit integer as it loses
                    --       some of the precision resulting in the wrong connection id
                    --       being captured during json_decode. Because of this, we have
                    --       to parse by hand the connection id from a string
                    connection = utils.parse_json_str_for_value(line, 'id')
                else
                    log.fmt_error('Unexpected msg: %s', msg)
                end
            end
        end,
        on_stderr_line = function(line)
            if line ~= nil then
                table.insert(error_lines, line)
            end
        end
    })

    return handle
end

return M
