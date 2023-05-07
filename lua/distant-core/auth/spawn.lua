local AuthHandler = require('distant-core.auth.handler')
local log = require('distant-core.log')
local utils = require('distant-core.utils')

--- Spawn a command that does some authentication and eventually returns an id upon success
--- @param opts {cmd:string|string[], auth?:distant.core.auth.Handler}
--- @param cb fun(err:string|nil, connection:string|nil)
--- @return distant.core.utils.JobHandle
return function(opts, cb)
    opts = opts or {}
    assert(opts.cmd, 'missing cmd')

    local handle, connection, error_lines
    connection = nil
    error_lines = {}

    -- Use provided auth handler, defaulting to a fresh instance if none provided
    --- @type distant.core.auth.Handler
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
            -- NOTE: We need to avoid exit code 143, which is neovim killing the process,
            --       when we successfully got a connection
            if code == 143 and connection then
                return cb(nil, connection)
            end

            local error_msg = '???'
            if not vim.tbl_isempty(error_lines) then
                error_msg = table.concat(error_lines, '\n')
            end

            error_msg = 'Failed (' .. tostring(code) .. '): ' .. error_msg
            return cb(error_msg)
        end,
        on_stdout_line = function(line)
            if line ~= nil and line ~= "" then
                --- @type table
                local msg = assert(vim.fn.json_decode(line), 'Invalid JSON from line')

                if auth:is_auth_request(msg) then
                    --- @diagnostic disable-next-line:redefined-local
                    auth:handle_request(msg, function(msg)
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
