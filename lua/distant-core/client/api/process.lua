local Error = require('distant-core.client.api.error')
local log   = require('distant-core.log')
local utils = require('distant-core.utils')

--- Represents a remote process.
--- @class DistantApiProcess
--- @field private __internal DistantApiProcessInternal
local M     = {}
M.__index   = M

--- @alias Stdout integer[]
--- @alias Stderr integer[]

--- @class DistantApiProcessInternal
--- @field id? integer
--- @field on_done? fun(opts:{success:boolean, exit_code:integer|nil, stdout:Stdout, stderr:Stderr})
--- @field on_stdout? fun(stdout:Stdout)
--- @field on_stderr? fun(stderr:Stderr)
--- @field transport DistantApiTransport
--- @field status {state:'inactive'|'active'|'done', success:boolean, exit_code?:integer}
--- @field stdin integer[]
--- @field stdout integer[]
--- @field stderr integer[]
--- @field timeout? integer
--- @field interval? integer

--- @param opts {transport:DistantApiTransport}
--- @return DistantApiProcess
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
        local id = assert(tonumber(payload.id), 'Malformed process spawned event! Missing id.')
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
        local id = assert(tonumber(payload.id), 'Malformed process done event! Missing id.')
        local success = assert(payload.success, 'Malformed process done event! Missing success.')
        local exit_code = tonumber(payload.code)
        if self:id() ~= id then
            log.fmt_warn('Received a "proc_done" event with id %s that does not match %s', id, self:id())
        end
        self.__internal.status.state = 'done'
        self.__internal.status.success = success
        self.__internal.status.exit_code = exit_code

        if type(self.__internal.on_done) == 'function' then
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
        local id = assert(tonumber(payload.id), 'Malformed process stdout event! Missing id.')
        -- local id = string.format('%.f', payload.id)
        local data = assert(payload.data, 'Malformed process stdout event! Missing data.')
        if self:id() ~= id then
            log.fmt_warn('Received a "proc_stdout" event with id %s that does not match %s', id, self:id())
        end

        if type(self.__internal.on_stdout) == 'function' then
            self.__internal.on_stdout(data)
        else
            for _, byte in ipairs(data) do
                table.insert(self.__internal.stdout, byte)
            end
        end
        return true
    elseif payload.type == 'proc_stderr' then
        local id = assert(tonumber(payload.id), 'Malformed process stderr event! Missing id.')
        -- local id = string.format('%.f', payload.id)
        local data = assert(payload.data, 'Malformed process stderr event! Missing data.')
        if self:id() ~= id then
            log.fmt_warn('Received a "proc_stderr" event with id %s that does not match %s', id, self:id())
        end

        if type(self.__internal.on_stderr) == 'function' then
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

--- @class DistantApiProcessSpawnOpts
--- @field cmd string|string[]
--- @field env? table<string, string>
--- @field cwd? string
--- @field pty? PtySize
---
--- @field stdin? integer[]|string #initial stdin to feed to process
--- @field on_stdout? fun(stdout:Stdout)
--- @field on_stderr? fun(stderr:Stderr)
--- @field timeout? number
--- @field interval? number

--- @class DistantApiProcessSpawnResults
--- @field success boolean
--- @field exit_code? integer
--- @field stdout Stdout
--- @field stderr Stderr

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
--- @param opts DistantApiProcessSpawnOpts
--- @param cb? fun(err?:DistantApiError, results?:DistantApiProcessSpawnResults)
function M:spawn(opts, cb)
    local tx, rx = utils.oneshot_channel(
        opts.timeout or self.__internal.transport.config.timeout,
        opts.interval or self.__internal.transport.config.interval
    )

    self.__internal.on_done = function(results)
        if type(cb) == 'function' then
            cb(nil, results)
        else
            tx({ results = results })
        end
    end
    self.__internal.on_stdout = opts.on_stdout
    self.__internal.on_stderr = opts.on_stderr
    self.__internal.timeout = opts.timeout
    self.__internal.interval = opts.timeout

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
            if type(cb) == 'function' then
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
        local err, msg = rx()
        if err then
            return Error:new({
                kind = Error.kinds.timed_out,
                description = err,
            })
        elseif msg.err then
            return Error:new({
                kind = Error.kinds.invalid_data,
                description = msg.err,
            })
        else
            return nil, msg.results
        end
    end
end

--- Writes to the stdin of the process if it is running.
--- @param data integer[]|string #initial stdin to feed to process
--- @param cb? fun(err?:DistantApiError, payload?:{type:'ok'}) #optional callback to report write confirmation
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

        if type(cb) == 'function' then
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
        cb = cb,
        verify = function(payload)
            return payload.type == 'ok'
        end,
        timeout = self.__internal.timeout,
        interval = self.__internal.interval,
    })
end

--- @class PtySize
--- @field rows integer
--- @field cols integer
--- @field pixel_width? integer
--- @field pixel_height? integer

--- Resizes the pty if the process is using a pty.
--- @param size PtySize
--- @param cb? fun(err?:DistantApiError, payload?:{type:'ok'}) #optional callback to report resize confirmation
function M:resize_pty(size, cb)
    return self.__internal.transport:send({
        payload = {
            type = 'proc_resize_pty',
            id = self:id(),
            size = size,
        },
        cb = cb,
        verify = function(payload)
            return payload.type == 'ok'
        end,
        timeout = self.__internal.timeout,
        interval = self.__internal.interval,
    })
end

--- Kills the process if it is running.
--- @param cb? fun(err?:DistantApiError, payload?:{type:'ok'}) #optional callback to report kill confirmation
function M:kill(cb)
    return self.__internal.transport:send({
        payload = {
            type = 'proc_kill',
            id = self:id(),
        },
        cb = cb,
        verify = function(payload)
            return payload.type == 'ok'
        end,
        timeout = self.__internal.timeout,
        interval = self.__internal.interval,
    })
end

return M
