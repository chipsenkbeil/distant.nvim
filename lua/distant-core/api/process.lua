local Error = require('distant-core.api.error')
local log   = require('distant-core.log')
local utils = require('distant-core.utils')

--- Represents a remote process.
--- @class distant.core.api.Process
--- @field private __internal distant.core.api.process.Internal
local M     = {}
M.__index   = M

--- @alias distant.core.api.process.Stdout integer[]
--- @alias distant.core.api.process.Stderr integer[]

--- @class distant.core.api.process.Internal
--- @field id? integer
--- @field on_done? fun(opts:distant.core.api.process.SpawnResults)
--- @field on_stdout? fun(stdout:distant.core.api.process.Stdout)
--- @field on_stderr? fun(stderr:distant.core.api.process.Stderr)
--- @field transport distant.core.api.Transport
--- @field status {state:'inactive'|'active'|'done', success:boolean, exit_code?:integer}
--- @field stdin integer[]
--- @field stdout integer[]
--- @field stderr integer[]
--- @field timeout? integer
--- @field interval? integer

--- @param opts {transport:distant.core.api.Transport}
--- @return distant.core.api.Process
function M:new(opts)
    local instance = {}
    setmetatable(instance, M)
    instance.__internal = {
        transport = opts.transport,
        status = { state = 'inactive', success = false },
        stdin = {},
        stdout = {},
        stderr = {},
    }

    return instance
end

--- Processes the payload of process events.
--- @param payload table
--- @return boolean #true if valid payload, otherwise false
function M:handle(payload)
    if payload.type == 'proc_spawned' then
        local id = assert(tonumber(payload.id), 'Malformed process spawned event! Missing id. ' .. vim.inspect(payload))
        if self:id() then
            log.fmt_warn('Received a "proc_spawned" event with id %s, but already started with id %s', id, self:id())
        end
        self.__internal.id = id
        self.__internal.status.state = 'active'

        -- If we have any queued stdin, we can now send it
        if not vim.tbl_isempty(self.__internal.stdin) then
            self:write_stdin(self.__internal.stdin, function(err)
                if err then
                    log.fmt_error('Failed to write queued stdin: %s', err)
                end
            end)
            self.__internal.stdin = {}
        end

        return true
    elseif payload.type == 'proc_done' then
        local id = assert(tonumber(payload.id), 'Malformed process done event! Missing id. ' .. vim.inspect(payload))
        local success = payload.success
        assert(success ~= nil, 'Malformed process done event! Missing success.' .. vim.inspect(payload))

        local exit_code = tonumber(payload.code)
        if self:id() ~= id then
            log.fmt_warn('Received a "proc_done" event with id %s that does not match %s', id, self:id())
        end
        self.__internal.status.state = 'done'
        self.__internal.status.success = success
        self.__internal.status.exit_code = exit_code

        if self.__internal.on_done and utils.callable(self.__internal.on_done) then
            self.__internal.on_done({
                success = success,
                exit_code = exit_code,
                stdout = self.__internal.stdout,
                stderr = self.__internal.stderr,
            })
            self.__internal.stdout = {}
            self.__internal.stderr = {}
        end
        return true
    elseif payload.type == 'proc_stdout' then
        local id = assert(tonumber(payload.id), 'Malformed process stdout event! Missing id. ' .. vim.inspect(payload))
        -- local id = string.format('%.f', payload.id)
        local data = assert(payload.data, 'Malformed process stdout event! Missing data. ' .. vim.inspect(payload))
        if self:id() ~= id then
            log.fmt_warn('Received a "proc_stdout" event with id %s that does not match %s', id, self:id())
        end

        if self.__internal.on_stdout and utils.callable(self.__internal.on_stdout) then
            self.__internal.on_stdout(data)
        else
            for _, byte in ipairs(data) do
                table.insert(self.__internal.stdout, byte)
            end
        end
        return true
    elseif payload.type == 'proc_stderr' then
        local id = assert(tonumber(payload.id), 'Malformed process stderr event! Missing id. ' .. vim.inspect(payload))
        -- local id = string.format('%.f', payload.id)
        local data = assert(payload.data, 'Malformed process stderr event! Missing data. ' .. vim.inspect(payload))
        if self:id() ~= id then
            log.fmt_warn('Received a "proc_stderr" event with id %s that does not match %s', id, self:id())
        end

        if self.__internal.on_stderr and utils.callable(self.__internal.on_stderr) then
            self.__internal.on_stderr(data)
        else
            for _, byte in ipairs(data) do
                table.insert(self.__internal.stderr, byte)
            end
        end
        return true
    else
        log.fmt_warn('Process received unexpected payload: %s', payload)
        return false
    end
end

--- Returns the id of the process, if it has started.
--- @return integer|nil
function M:id()
    return self.__internal.id
end

--- Returns the status of the process.
--- @return 'inactive'|'active'|'done'
function M:status()
    return self.__internal.status.state
end

--- Returns whether or not the process is finished.
--- @return boolean
function M:is_done()
    return self:status() == 'done'
end

--- Returns whether or not the process exited successfully.
--- @return boolean
function M:is_success()
    return self.__internal.status.success
end

--- Returns the exit code of the process after exiting.
--- @return integer|nil
function M:exit_code()
    return self.__internal.status.exit_code
end

--- Returns the stdout captured by the process. Only available
--- when a process created without `on_stdout` or done callbacks.
--- @return integer[]
function M:stdout()
    return self.__internal.stdout
end

--- Returns the stderr captured by the process. Only available
--- when a process created without `on_stderr` or done callbacks.
--- @return integer[]
function M:stderr()
    return self.__internal.stderr
end

--- @class distant.core.api.process.SpawnOpts
--- @field cmd string|string[]
--- @field env? table<string, string>
--- @field cwd? string
--- @field pty? distant.core.api.process.PtySize
---
--- @field stdin? integer[]|string #initial stdin to feed to process
--- @field on_stdout? fun(stdout:distant.core.api.process.Stdout)
--- @field on_stderr? fun(stderr:distant.core.api.process.Stderr)
--- @field timeout? number
--- @field interval? number

--- @class distant.core.api.process.SpawnResults
--- @field success boolean
--- @field exit_code? integer
--- @field stdout distant.core.api.process.Stdout
--- @field stderr distant.core.api.process.Stderr

--- Spawns the process. If a callback is provided, it will be invoked when the process
--- finishes and be provided the exit code, stdout, and stderr of the process. If no
--- callback is provided, the method will block until the process completes, returning
--- the exit code, stdout, and stderr.
---
--- * `stdin` can be provided to feed stdin to the process once it is spawned. To
---   dynamically send stdin, invoke the `write_stdin` method of the spawned process
---   that is returned from the asynchronous callback approach.
--- * `on_stdout` can be provided to receive the stdout as it is received from the process.
---   This will result in no stdout being returned at the end of the process.
--- * `on_stderr` can be provided to receive the stderr as it is received from the process.
---   This will result in no stderr being returned at the end of the process.
---
--- @param opts distant.core.api.process.SpawnOpts
--- @param cb? fun(err?:distant.core.api.Error, results?:distant.core.api.process.SpawnResults)
--- @return distant.core.api.Error|nil,distant.core.api.process.SpawnResults|nil
function M:spawn(opts, cb)
    local timeout = opts.timeout or self.__internal.transport.config.timeout
    local interval = opts.interval or self.__internal.transport.config.interval
    local tx, rx = utils.oneshot_channel(timeout, interval)

    self.__internal.on_done = function(results)
        if cb and utils.callable(cb) then
            cb(nil, results)
        else
            tx({ results = results })
        end
    end
    self.__internal.on_stdout = opts.on_stdout
    self.__internal.on_stderr = opts.on_stderr
    self.__internal.timeout = timeout
    self.__internal.interval = timeout

    -- Build our command
    local cmd = opts.cmd
    if type(cmd) == 'table' then
        cmd = table.concat(cmd, ' ')
    end

    -- Build our environment in the form of 'key1="value1",key2="value2"'
    --- @type string|nil
    local env = nil
    if opts.env then
        env = ''

        for key, value in pairs(opts.env) do
            -- TODO: Support better quote escape mechanism
            value = value:gsub('"', '\\"')

            env = string.format('%s,%s="%s"', env, key, value)
        end
    end

    -- Queue up any stdin we want to send
    if opts.stdin then
        self:write_stdin(opts.stdin)
    end

    self.__internal.transport:send_async({
        payload = {
            type = 'proc_spawn',
            cmd = cmd,
            environment = env,
            current_dir = opts.cwd,
            pty = opts.pty,
        },
        more = function(payload)
            local ty = payload.type

            -- NOTE: We do NOT include proc_done because we want the callback
            --       to terminate once the done payload is received!
            return ty == 'proc_spawned' or ty == 'proc_stdout' or ty == 'proc_stderr'
        end,
    }, function(payload)
        if not self:handle(payload) then
            if cb and utils.callable(cb) then
                cb(Error:new({
                    kind = Error.kinds.invalid_data,
                    description = 'Invalid response payload: ' .. vim.inspect(payload),
                }), nil)
            else
                tx({ err = 'Invalid response payload: ' .. vim.inspect(payload) })
            end
        end
    end)

    -- Running synchronously, so pull in our results
    if not cb then
        --- @type boolean, string|{err:string}|{results:distant.core.api.process.SpawnResults}
        local status, results = pcall(rx)

        if not status then
            return Error:new({
                kind = Error.kinds.timed_out,
                --- @cast results string
                description = results,
            })
        elseif results.err then
            return Error:new({
                kind = Error.kinds.invalid_data,
                description = results.err,
            })
        elseif results.results then
            return nil, results.results
        end
    end
end

--- Writes to the stdin of the process if it is running.
--- @param data integer[]|string #initial stdin to feed to process
--- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.OkPayload) #optional callback to report write confirmation
--- @return distant.core.api.Error|nil, distant.core.api.OkPayload|nil
function M:write_stdin(data, cb)
    -- Convert string to byte array
    if type(data) == 'string' then
        data = { string.byte(data, 1, string.len(data)) }
    end

    -- Not ready yet, so queue up the stdin to be sent later
    if self:status() ~= 'active' then
        for _, byte in ipairs(data) do
            table.insert(self.__internal.stdin, byte)
        end

        if cb and utils.callable(cb) then
            return
        else
            return nil, { type = 'ok' }
        end
    end

    return self.__internal.transport:send({
        payload = {
            type = 'proc_stdin',
            id = self:id(),
            data = data,
        },
        verify = function(payload)
            return payload.type == 'ok'
        end,
        timeout = self.__internal.timeout,
        interval = self.__internal.interval,
    }, cb)
end

--- @class distant.core.api.process.PtySize
--- @field rows integer
--- @field cols integer
--- @field pixel_width? integer
--- @field pixel_height? integer

--- Resizes the pty if the process is using a pty.
--- @param size distant.core.api.process.PtySize
--- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.OkPayload)
--- @return distant.core.api.Error|nil, distant.core.api.OkPayload|nil
function M:resize_pty(size, cb)
    return self.__internal.transport:send({
        payload = {
            type = 'proc_resize_pty',
            id = self:id(),
            size = size,
        },
        verify = function(payload)
            return payload.type == 'ok'
        end,
        timeout = self.__internal.timeout,
        interval = self.__internal.interval,
    }, cb)
end

--- Kills the process if it is running.
--- @param cb? fun(err?:distant.core.api.Error, payload?:distant.core.api.OkPayload)
--- @return distant.core.api.Error|nil, distant.core.api.OkPayload|nil
function M:kill(cb)
    return self.__internal.transport:send({
        payload = {
            type = 'proc_kill',
            id = self:id(),
        },
        verify = function(payload)
            return payload.type == 'ok'
        end,
        timeout = self.__internal.timeout,
        interval = self.__internal.interval,
    }, cb)
end

return M
