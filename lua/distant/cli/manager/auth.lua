local log = require('distant.log')
local utils = require('distant.utils')

local M = {}

--- @class AuthHandler
--- @field on_authenticate fun(msg:AuthHandlerMsg):string[]|nil
--- @field on_verify_host fun(host:string):boolean|nil
--- @field on_info fun(text:string)|nil
--- @field on_error fun(err:string)|nil
--- @field on_unknown fun(x:any)|nil

--- @class AuthHandlerMsg
--- @field extra table<string, string>|nil
--- @field questions {text:string, extra:table<string, string>|nil}[]

--- @return AuthHandler
local function make_auth_handler()
    return {
        --- @param msg AuthHandlerMsg
        --- @return string[]
        on_authenticate = function(msg)
            print('msg = ' .. vim.inspect(msg))
            if msg.extra then
                if msg.extra.username then
                    print('Authentication for ' .. msg.extra.username)
                end
                if msg.extra.instructions then
                    print(msg.extra.instructions)
                end
            end

            local answers = {}
            for _, question in ipairs(msg.questions) do
                if question.extra and question.extra.echo == 'true' then
                    table.insert(answers, vim.fn.input(question.text))
                else
                    table.insert(answers, vim.fn.inputsecret(question.text))
                end
            end
            return answers
        end,

        --- @param host string
        --- @return boolean
        on_verify_host = function(host)
            local answer = vim.fn.input(string.format('%s\nEnter [y/N]> ', host))
            if answer ~= nil then
                answer = vim.trim(answer)
            end
            return answer == 'y' or answer == 'Y' or answer == 'yes' or answer == 'YES'
        end,

        --- @param text string
        on_info = function(text)
            print(text)
        end,

        --- @param err string
        on_error = function(err)
            log.fmt_error('Authentication error: %s', err)
        end,

        --- @param x any
        on_unknown = function(x)
            log.fmt_error('Unknown authentication event received: %s', x)
        end,
    }
end

--- Authentication event handler
--- @param auth AuthHandler
--- @param msg table
--- @param reply fun(msg:table)
--- @return boolean #true if okay, otherwise false
local function handle_auth_msg(auth, msg, reply)
    local type = msg.type

    if type == 'challenge' then
        reply({
            type = 'challenge',
            answers = auth.on_authenticate(msg)
        })
        return true
    elseif type == 'info' then
        auth.on_info(msg.text)
        return true
    elseif type == 'verify' then
        reply({
            type = 'verify',
            valid = auth.on_verify_host(msg.text)
        })
        return true
    elseif type == 'error' then
        auth.on_error(vim.inspect(msg))
        return false
    else
        auth.on_unknown(msg)
        return false
    end
end

--- @param msg {type:string}
--- @return boolean
local function is_auth_msg(msg)
    return msg and type(msg.type) == 'string' and vim.tbl_contains({
        'challenge',
        'verify',
        'info',
        'error',
    }, msg.type)
end

--- Spawn a command that does some authentication and eventually returns an id upon success
--- @param opts {cmd:string|string[], auth:AuthHandler|nil}
--- @param cb fun(err:string|nil, connection:string|nil)
--- @return JobHandle
function M.spawn(opts, cb)
    local handle, connection, error_lines
    connection = nil
    error_lines = {}

    -- Use any custom auth methods, defaulting to standard handler methods if missing
    local auth = vim.tbl_deep_extend('keep', opts.auth or {}, make_auth_handler())

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
        end;
        on_failure = function(code)
            local error_msg = '???'
            if not vim.tbl_isempty(error_lines) then
                error_msg = table.concat(error_lines, '\n')
            end

            error_msg = 'Failed (' .. tostring(code) .. '): ' .. error_msg
            return cb(error_msg)
        end;
        on_stdout_line = function(line)
            if line ~= nil and line ~= "" then
                local msg = vim.fn.json_decode(line)
                if is_auth_msg(msg) then
                    --- @diagnostic disable-next-line:redefined-local
                    handle_auth_msg(auth, msg, function(msg)
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
        end;
        on_stderr_line = function(line)
            if line ~= nil then
                table.insert(error_lines, line)
            end
        end
    })

    return handle
end

return M
