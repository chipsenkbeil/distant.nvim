local AuthHandler = require('distant-core.auth')

------------------------------------------------------------------------------
-- CLASS DEFINITION
------------------------------------------------------------------------------

--- @alias distant.core.job.OnStdoutLine fun(job:distant.core.Job, line:string)
--- @alias distant.core.job.OnStderrLine fun(job:distant.core.Job, line:string)

--- Represents an external job.
--- @class distant.core.Job
--- @field private __id integer|nil # assigned once job started
--- @field private __auth_handler distant.core.AuthHandler|nil # if handling authentication, will be assigned
--- @field private __stdout_lines string[]|nil # if indicated, will collect lines here
--- @field private __stderr_lines string[]|nil # if indicated, will collect lines here
--- @field private __on_stdout_line? distant.core.job.OnStdoutLine
--- @field private __on_stderr_line? distant.core.job.OnStderrLine
--- @field private __exit_status distant.core.job.ExitStatus|nil # populated once finished
local M = {}
M.__index = M

--- Creates a new job handler without starting it.
---
--- # Options
---
--- * `buffer_stdout` - if true and no stdout handler has been set, will store
---   lines of stdout into an internal buffer available from `stdout_lines()`.
--- * `buffer_stderr` - if true and no stderr handler has been set, will store
---   lines of stderr into an internal buffer available from `stderr_lines()`.
---
--- @param opts? {buffer_stdout?:boolean, buffer_stderr?:boolean}
--- @return distant.core.Job
function M:new(opts)
    local instance = {}
    setmetatable(instance, M)

    opts = opts or {}
    if opts.buffer_stdout then
        instance.__stdout_lines = {}
    end
    if opts.buffer_stderr then
        instance.__stderr_lines = {}
    end

    return instance
end

--- Configures authentication handling with the job.
---
--- * If `handler` is falsy, authentication will be disabled (default)
--- * If `handler` is true, a default authentication handler will be assigned to the job.
--- * If `handler` is a handler, it will be assigned to the job.
---
--- In the case that a handler is assigned to the job, stdout will be specially processed
--- based on whether the received stdout line matches a distant authentication message. If
--- it does, the message is processed by the handler; otherwise, the message is handled by
--- the regular stdout handler or buffered into stdout lines.
---
--- @param handler boolean|distant.core.AuthHandler
--- @return distant.core.Job
function M:authentication(handler)
    if handler then
        if handler == true then
            self.__auth_handler = AuthHandler:new()
        else
            self.__auth_handler = handler
        end
    else
        self.__auth_handler = nil
    end

    return self
end

--- Sets the handler to be invoked when a new line is received on stdout.
--- @param f distant.core.job.OnStdoutLine
--- @return distant.core.Job
function M:on_stdout_line(f)
    self.__on_stdout_line = f
    return self
end

--- Sets the handler to be invoked when a new line is received on stderr.
--- @param f distant.core.job.OnStderrLine
--- @return distant.core.Job
function M:on_stderr_line(f)
    self.__on_stderr_line = f
    return self
end

------------------------------------------------------------------------------
-- SIGNAL DEFINITION & API
------------------------------------------------------------------------------

--- POSIX-compliant signal table, using the portable number.
--- @enum distant.core.job.Signal
local SIGNAL = {
    --- Process abort signal
    SIGABRT = 6,
    --- Alarm clock
    SIGALRM = 14,
    --- Access to an undefined portion of a memory object
    SIGBUS = nil,
    --- Child process terminated, stopped, or continued
    SIGCHLD = nil,
    --- Continue executing, if stopped
    SIGCONT = nil,
    --- Erroneous arithmetic operation
    SIGFPE = 8,
    --- Hangup
    SIGHUP = 1,
    --- Illegal instruction
    SIGILL = 4,
    --- Terminal interrupt signal
    SIGINT = 2,
    --- Kill (cannot be caught or ignored)
    SIGKILL = 9,
    --- Write on a pipe with no one to read it
    SIGPIPE = 13,
    --- Pollable event
    SIGPOLL = nil,
    --- Profiling timer expired
    SIGPROF = nil,
    --- Terminal quit signal
    SIGQUIT = 3,
    --- Invalid memory reference
    SIGSEGV = 11,
    --- Stop executing (cannot be caught or ignored)
    SIGSTOP = nil,
    --- Bad system call
    SIGSYS = nil,
    --- Termination signal
    SIGTERM = 15,
    --- Trace/breakpoint trap
    SIGTRAP = 5,
    --- Terminal stop signal
    SIGTSTP = nil,
    --- Background process attempting read
    SIGTTIN = nil,
    --- Background process attempting write
    SIGTTOU = nil,
    --- User-defined signal 1
    SIGUSR1 = nil,
    --- User-defined signal 2
    SIGUSR2 = nil,
    --- Out-of-band data is available at a socket
    SIGURG = nil,
    --- Virtual timer expired
    SIGVTALRM = nil,
    --- CPU time limit exceeded
    SIGXCPU = nil,
    --- File size limit exceeded
    SIGXFSZ = nil,
    --- Terminal window size changed
    SIGWINCH = nil,
}

--- Types of signals available.
M.signal = SIGNAL

--- Returns true if given exit code represents a signal.
--- @return boolean
function M.is_signal(exit_code)
    return type(exit_code) == 'number' and exit_code > 128
end

--- Returns the represented signal if exit code is a signal.
--- @return distant.core.job.Signal|nil
function M.to_signal(exit_code)
    local name = M.to_signal_name(exit_code)
    if name then
        return SIGNAL[name]
    end
end

--- Returns the represented signal name if exit code is a signal.
--- @return string|nil signal_name
function M.to_signal_name(exit_code)
    if M.is_signal(exit_code) then
        for key, value in pairs(SIGNAL) do
            if value == exit_code - 128 then
                return key
            end
        end
    end
end

------------------------------------------------------------------------------
-- JOB START API
------------------------------------------------------------------------------

--- Produces a function that is used to collect stdout/stderr and invoke the `cb` when a full line is available.
--- @param job distant.core.Job
--- @param cb fun(job:distant.core.Job, line:string)
local function make_on_data(job, cb)
    local lines = { '' }
    return function(_, data, _)
        local send_back = vim.schedule_wrap(function(line)
            if type(line) == 'string' and line ~= '' then
                cb(job, line)
            end
        end)

        -- Build up our lines by adding any partial line data to the current
        -- partial line, and then treating all additional data as extra lines,
        -- keeping in mind that the final line is also partial
        lines[#lines] = lines[#lines] .. data[1]
        for i, line in ipairs(data) do
            if i > 1 then
                table.insert(lines, line)
            end
        end

        -- End of stream, so write whatever we have in our buffer
        if #data == 1 and data[1] == '' then
            send_back(lines[1])

            -- Otherwise, we want to report all of our lines except the last one
            -- which may be partial
        else
            for i, v in ipairs(lines) do
                if i < #data then
                    send_back(v)
                end
            end

            -- Remove all lines but the last one
            lines = { lines[#lines] }
        end
    end
end

--- Attempts to parse a line as a JSON table.
--- @param line string
--- @return table|nil json_table
local function try_parse_json_table(line)
    --- @type boolean, any
    local success, json = pcall(vim.json.decode, line, {
        luanil = { array = true, object = true }
    })

    if success and type(json) == 'table' then
        return json
    end
end

--- @class distant.core.job.ExitStatus
--- @field success boolean # true if the process exited cleanly
--- @field exit_code integer # exit code returned by process
--- @field signal distant.core.job.Signal|nil # signal if exit code represented termination by signal
--- @field stdout string[] # if buffered, will be lines of stdout, otherwise an empty list
--- @field stderr string[] # if buffered, will be lines of stderr, otherwise an empty list

--- Start an async job using the given cmd and options.
---
--- @param opts {cmd:string|string[], env?:table<string, string>}
--- @param cb? fun(err?:string, exit_status:distant.core.job.ExitStatus)
--- @return boolean # true if successfully started, otherwise false
function M:start(opts, cb)
    local cmd = assert(opts.cmd, 'Missing cmd to start job')

    -- Update the callback to be scheduled
    cb = vim.schedule_wrap(cb or function()
    end)

    --- @param job distant.core.Job
    --- @param line string
    local function on_stdout(job, line)
        local handler = self.__auth_handler

        -- If we are performing authentication, try to authenticate using the line as a JSON message
        --
        -- TODO: We cannot stop parsing the line and testing because both the manager
        --       and server can perform authentication steps. So the finished flag is
        --       a falsehood and we would end up not handling the server authentication
        --       once the manager authentication had finished! Is there a way to support
        --       checking for server vs manager authentication being finished?
        if handler then
            local msg = try_parse_json_table(line)
            if msg and handler:is_auth_request(msg) then
                local ok = handler:handle_request(msg, function(msg)
                    assert(
                        job:write(vim.json.encode(msg) .. '\n') > 0,
                        'Failed to response to authentication'
                    )
                end)

                assert(ok, 'Authentication handler failed')
                return
            end
        end

        -- Otherwise, handle the line like usual by either
        -- passing it to a custom handler or buffering it
        if self.__on_stdout_line then
            self.__on_stdout_line(job, line)
        elseif self.__stdout_lines ~= nil then
            table.insert(self.__stdout_lines, line)
        end
    end

    --- @param line string
    local on_stderr = self.__on_stderr_line or function(_, line)
        if self.__stderr_lines ~= nil then
            table.insert(self.__stderr_lines, line)
        end
    end

    -- Spawn the job and assign the id to it
    self.__id = vim.fn.jobstart(cmd, {
        env = opts.env,
        on_stdout = make_on_data(self, on_stdout),
        on_stderr = make_on_data(self, on_stderr),
        --- @param exit_code number
        on_exit = function(_, exit_code, _)
            local success = exit_code == 0
            local signal = self.to_signal(exit_code)
            local exit_status = {
                success = success,
                exit_code = exit_code,
                signal = signal,
                stdout = self.__stdout_lines or {},
                stderr = self.__stderr_lines or {},
            }

            -- Update our job to contain the status
            -- and report the status in our callback
            self.__exit_status = exit_status
            cb(nil, exit_status)
        end,
    })

    --- When we fail to spawn the job, we still want to provide an exit status,
    --- but it is one that is invalid. So things like exit_code are filled in
    --- with an arbitrary value.
    ---
    --- @return distant.core.job.ExitStatus
    local function make_invalid_status()
        return {
            success = false,
            exit_code = -1,
            signal = nil,
            stdout = {},
            stderr = {},
        }
    end

    -- If we get an invalid spawn result, report it to the callback
    if self.__id == 0 then
        cb('Invalid arguments: ' .. vim.inspect(cmd), make_invalid_status())
    elseif self.__id == -1 then
        cb('Cmd is not executable: ' .. vim.inspect(cmd), make_invalid_status())
    end

    -- Good to go if job id > 0
    return self.__id > 0
end

------------------------------------------------------------------------------
-- GENERAL JOB API
------------------------------------------------------------------------------

--- Returns the job's id. If the job has not been started, will fail.
--- @return number
function M:id()
    return assert(self.__id, 'Job not started')
end

--- Returns whether or not the job is running.
--- @return boolean
function M:is_running()
    if self.__id then
        return vim.fn.jobwait({ self.__id }, 0)[1] == -1
    else
        return false
    end
end

--- Returns the lines of stdout collected. Will be empty if not told to collect.
--- @return string[]
function M:stdout_lines()
    return self.__stdout_lines or {}
end

--- Returns the lines of stderr collected. Will be empty if not told to collect.
--- @return string[]
function M:stderr_lines()
    return self.__stderr_lines or {}
end

--- Returns the exit status and other information once the job has finished, otherwise nil.
--- @return distant.core.job.ExitStatus|nil
function M:exit_status()
    return self.__exit_status
end

--- @param data any
--- @return integer # number of bytes written, or 0 if failed
function M:write(data)
    if self.__id then
        return vim.fn.chansend(self.__id, data)
    else
        return 0
    end
end

--- Stops the job if it is running.
--- @return boolean # true if stopped, or false if not running or exited already
function M:stop()
    if self.__id then
        return vim.fn.jobstop(self.__id) == 1
    else
        return false
    end
end

return M
