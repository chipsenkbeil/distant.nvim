local AuthHandler = require('distant-core.auth.handler')
local log = require('distant-core.log')
local utils = require('distant-core.utils')

--- @class distant.core.auth.SpawnOpts
--- @field cmd string|string[]
--- @field auth? distant.core.auth.Handler
--- @field skip? fun(msg:table):boolean # if provided and returns true, will skip the result

--- Spawn a command that does some authentication and invokes `cb`
--- upon receiving a non-authentication message (or an error).
---
--- @param opts distant.core.auth.SpawnOpts
--- @param cb fun(err:string|nil, result:{line:string, msg:table}|nil)
--- @return distant.core.utils.JobHandle
return function(opts, cb)
    opts = opts or {}
    assert(opts.cmd, 'missing cmd')

    local handle, result, error_lines
    error_lines = {}

    --- @type {line:string, msg:table}|nil
    result = nil

    -- Use provided auth handler, defaulting to a fresh instance if none provided
    --- @type distant.core.auth.Handler
    local auth = opts.auth or AuthHandler:new()

    local skip = opts.skip or function(_) return false end

    handle = utils.job_start(opts.cmd, {
        on_success = function()
            if not vim.tbl_isempty(error_lines) then
                log.error(table.concat(error_lines, '\n'))
            end

            if not result then
                return cb('Completed, but missing result')
            else
                return cb(nil, result)
            end
        end,
        on_failure = function(code)
            -- NOTE: We need to avoid exit code 143, which is neovim killing the process,
            --       when we successfully got a connection
            if code == 143 and result then
                return cb(nil, result)
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
                elseif result == nil and not skip(msg) then
                    result = {
                        line = line,
                        msg = msg,
                    }
                elseif result ~= nil then
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
