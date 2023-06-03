local log = require('distant-core.log')
local utils = require('distant-core.utils')

local callable = utils.callable

--- @class distant.core.AuthHandler
--- @field finished boolean #true if handler has finished performing authentication
local M = {}
M.__index = M

--- @class distant.core.auth.NewOpts
--- @field on_challenge? fun(msg:distant.core.auth.OnChallengeMsg):string[]
--- @field on_error? fun(msg:distant.core.auth.OnErrorMsg)
--- @field on_finished? fun()
--- @field on_info? fun(text:string)
--- @field on_initialization? fun(msg:distant.core.auth.OnInitializationMsg):string[]
--- @field on_start_method? fun(method:string)
--- @field on_verification? fun(msg:distant.core.auth.OnVerificationMsg):boolean

--- Creates a new instance of the authentication handler.
---
--- Takes an optional collection of callbacks to invoke when receiving authentication requests.
---
--- @param opts? distant.core.auth.NewOpts
--- @return distant.core.AuthHandler
function M:new(opts)
    opts = opts or {}
    local instance = {}
    setmetatable(instance, M)

    if opts.on_challenge and callable(opts.on_challenge) then
        instance.on_challenge = function(_, msg)
            return opts.on_challenge(msg)
        end
    end

    if opts.on_error and callable(opts.on_error) then
        instance.on_error = function(_, msg)
            return opts.on_error(msg)
        end
    end

    if opts.on_finished and callable(opts.on_finished) then
        instance.on_finished = function(_)
            return opts.on_finished()
        end
    end

    if opts.on_info and callable(opts.on_info) then
        instance.on_info = function(_, msg)
            return opts.on_info(msg)
        end
    end

    if opts.on_initialization and callable(opts.on_initialization) then
        instance.on_initialization = function(_, msg)
            return opts.on_initialization(msg)
        end
    end

    if opts.on_start_method and callable(opts.on_start_method) then
        instance.on_start_method = function(_, msg)
            return opts.on_start_method(msg)
        end
    end

    if opts.on_verification and callable(opts.on_verification) then
        instance.on_verification = function(_, msg)
            return opts.on_verification(msg)
        end
    end

    return instance
end

--- Creates a dummy authentication handler that always returns the specified
--- `password` (or empty string) for password prompts and passes verification requests.
---
--- @param opts? {password?:string}
--- @return distant.core.AuthHandler
function M:dummy(opts)
    opts = opts or {}

    local password = opts.password or ''
    return M:new({
        on_challenge = function(msg)
            local answers = {}

            --- @diagnostic disable-next-line:unused-local
            for _, question in ipairs(msg.questions) do
                table.insert(answers, password)
            end

            return answers
        end,
        on_verification = function(_)
            return true
        end,
    })
end

--- Returns true if the provided message with a type is an authentication request.
---
--- Can also be given a raw line of text as the message and it will be parsed.
---
--- @param msg string|{type:string}
--- @return boolean
function M:is_auth_request(msg)
    if type(msg) == 'string' then
        --- @type boolean, any
        local success, json = pcall(vim.json.decode, msg, { luanil = { array = true, object = true } })
        if not success or type(json) ~= 'table' then
            return false
        end

        --- @cast json table
        msg = json
    end

    return msg and type(msg.type) == 'string' and vim.tbl_contains({
        'auth_initialization',
        'auth_start_method',
        'auth_challenge',
        'auth_verification',
        'auth_info',
        'auth_error',
        'auth_finished',
    }, msg.type)
end

--- @alias distant.core.auth.Request
--- | {type:'auth_initialization', methods:string[]}
--- | {type:'auth_start_method', method:string}
--- | {type:'auth_challenge', questions:distant.core.auth.Question[], extra?:distant.core.auth.Extra}}
--- | {type:'auth_info', text:string}
--- | {type:'auth_verification', kind:distant.core.auth.VerificationKind, text:string}
--- | {type:'auth_error', kind:string, text:string}
--- | {type:'auth_finished'}

--- @alias distant.core.auth.Question {text:string, extra?:distant.core.auth.Extra}
--- @alias distant.core.auth.Extra table<string, string>
--- @alias distant.core.auth.VerificationKind 'host'|'unknown'
--- @alias distant.core.auth.ErrorKind 'fatal'|'error'

--- Processes some message as an authentication request.
--- @param msg distant.core.auth.Request #incoming request message
--- @param reply fun(msg:table) #used to send a response message back
--- @return boolean #true if okay, otherwise false to indicate error/unknown
function M:handle_request(msg, reply)
    local type = msg.type

    if type == 'auth_initialization' then
        --- @cast msg {type:'auth_initialization', methods:string[]}
        reply({
            type = 'auth_initialization_response',
            methods = self:on_initialization(msg)
        })
        return true
    elseif type == 'auth_start_method' then
        --- @cast msg {type:'auth_start_method', method:string}
        self:on_start_method(msg.method)
        return true
    elseif type == 'auth_challenge' then
        --- @cast msg {type:'auth_challenge', questions:distant.core.auth.Question[], extra?:distant.core.auth.Extra}}
        reply({
            type = 'auth_challenge_response',
            answers = self:on_challenge(msg)
        })
        return true
    elseif type == 'auth_info' then
        --- @cast msg {type:'auth_info', text:string}
        self:on_info(msg.text)
        return true
    elseif type == 'auth_verification' then
        --- @cast msg {type:'auth_verification', kind:distant.core.auth.VerificationKind, text:string}
        reply({
            type = 'auth_verification_response',
            valid = self:on_verification(msg)
        })
        return true
    elseif type == 'auth_error' then
        --- @cast msg {type:'auth_error', kind:distant.core.auth.ErrorKind, text:string}
        self:on_error({ kind = msg.kind, text = msg.text })
        return false
    elseif type == 'auth_finished' then
        --- @cast msg {type:'auth_finished'}
        self:on_finished()
        return true
    else
        --- @cast msg {type:string}
        self:on_unknown(msg)
        return false
    end
end

--- Invoked when authentication is starting, containing available methods to use for authentication.
--- @alias distant.core.auth.OnInitializationMsg {methods:string[]}
--- @param msg distant.core.auth.OnInitializationMsg
--- @return string[] #authentication methods to use
function M:on_initialization(msg)
    return msg.methods
end

--- Invoked when an indicator that a new authentication method is starting during authentication.
--- @param method string
function M:on_start_method(method)
    log.fmt_trace('Beginning authentication method: %s', method)
end

--- Invoked when a request to answer some questions is received during authentication.
--- @alias distant.core.auth.OnChallengeMsg {questions:distant.core.auth.Question[], extra?:distant.core.auth.Extra}
--- @param msg distant.core.auth.OnChallengeMsg
--- @return string[]
function M:on_challenge(msg)
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
end

--- Invoked when a request to verify some information is received during authentication.
--- @alias distant.core.auth.OnVerificationMsg {kind:distant.core.auth.VerificationKind, text:string}
--- @param msg distant.core.auth.OnVerificationMsg
--- @return boolean
function M:on_verification(msg)
    local answer = vim.fn.input(string.format('%s\nEnter [y/N]> ', msg.text))
    if answer ~= nil then
        answer = vim.trim(answer)
    end
    return answer == 'y' or answer == 'Y' or answer == 'yes' or answer == 'YES'
end

--- Invoked when information is received during authentication.
--- @param text string
function M:on_info(text)
    print(text)
end

--- Invoked when an error is encountered during authentication.
--- Fatal errors indicate the end of authentication.
---
--- @alias distant.core.auth.OnErrorMsg {kind:distant.core.auth.ErrorKind, text:string}
--- @param err distant.core.auth.OnErrorMsg
function M:on_error(err)
    log.fmt_error('Authentication error: %s', err.text)

    if not self.finished then
        self.finished = err.kind == 'fatal'
    end
end

--- Invoked when authentication is finishd
function M:on_finished()
    log.trace('Authentication finished')
    self.finished = true
end

--- Invoked whenever an unknown authentication msg is received.
--- @param x any
function M:on_unknown(x)
    log.fmt_error('Unknown authentication event received: %s', x)
end

return M
