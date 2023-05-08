local auth             = require('distant-core.auth')
local builder          = require('distant-core.builder')
local Destination      = require('distant-core.destination')
local Client           = require('distant-core.client')
local log              = require('distant-core.log')
local utils            = require('distant-core.utils')

local DEFAULT_TIMEOUT  = 1000
local DEFAULT_INTERVAL = 100

--- Represents a distant server.
--- @class distant.core.Server
--- @field private config distant.core.server.Config
--- @field private handle? distant.core.utils.JobHandle
local M                = {}
M.__index              = M

--- @class distant.core.server.Config
--- @field binary string #path to distant binary to use

--- Creates a new instance of a distant server.
--- @param opts distant.core.server.Config
--- @return distant.core.Server
function M:new(opts)
    local instance = {}
    setmetatable(instance, M)
    instance.config = {
        binary = opts.binary,
    }

    return instance
end

--- @class distant.core.server.ListenOpts
--- @field config? string
--- @field current_dir? string
--- @field log_file? string
--- @field log_level? string
--- @field port? number|{start:number, n?:number}
--- @field shutdown? {key:'after'|'lonely'|'never', value?:number}
--- @field use_ipv6? boolean
--- @field on_exit? fun(err?:string, code?:number)
--- @field timeout? number
--- @field interval? number

--- @class distant.core.server.Details
--- @field port number
--- @field key string

--- Spawn a new server to listen. If `cb` not provided, will run synchronously
--- to return the server's details. Otherwise will pass details to callback.
---
--- @param opts distant.core.server.ListenOpts
--- @param cb? fun(details:distant.core.server.Details) #invoked when the server is ready
--- @return string|nil err, distant.core.server.Details|nil details
function M:listen(opts, cb)
    opts = opts or {}

    local cmd = builder.server.listen():set_from_tbl({
        config      = opts.config,
        current_dir = opts.current_dir,
        log_file    = opts.log_file,
        log_level   = opts.log_level,
        use_ipv6    = opts.use_ipv6,
    })

    local port = opts.port
    if type(port) == 'number' then
        cmd = cmd:set_port(port)
    elseif type(port) == 'table' then
        cmd = cmd:set_port(port.start, port.n)
    end

    if opts.shutdown then
        cmd = cmd:set_shutdown(opts.shutdown.key, opts.shutdown.value)
    end

    --- @type string[]
    cmd = cmd:as_list()
    table.insert(cmd, 1, self.config.binary)

    -- If no callback provided, we will run synchronously
    -- and swap out the `cb` with `tx` from the channel
    local rx
    if not cb then
        cb, rx = utils.oneshot_channel(
            opts.timeout or DEFAULT_TIMEOUT,
            opts.interval or DEFAULT_INTERVAL
        )
    end

    local ready = false
    local on_exit = opts.on_exit
    local error_lines = {}
    self.handle = utils.job_start(cmd, {
        on_success = function()
            if on_exit then
                on_exit(nil, 0)
            end
        end,
        on_failure = function(code)
            local error_msg = '???'
            if not vim.tbl_isempty(error_lines) then
                error_msg = table.concat(error_lines, '\n')
            end

            error_msg = 'Failed (' .. tostring(code) .. '): ' .. error_msg

            -- NOTE: Don't trigger if code is 143 as that is neovim terminating the server on exit
            if on_exit and code ~= 143 then
                on_exit(error_msg, code)
            end
        end,
        on_stdout_line = function(line)
            if ready then
                return
            end

            if type(line) == 'string' then
                -- The server should print out a line in the form of distant://:{password}@{host}:{port}
                local destination = Destination:try_parse(vim.trim(line))
                if destination then
                    ready = true
                    if cb then
                        cb({
                            key = assert(
                                destination.password,
                                'Invalid destination, missing password: ' .. destination:as_string()
                            ),
                            port = assert(
                                destination.port,
                                'Invalid destination, missing port: ' .. destination:as_string()
                            ),
                        })
                    end
                end
            end
        end,
        on_stderr_line = function(line)
            if line ~= nil and on_exit then
                table.insert(error_lines, line)
            end
        end,
    })

    if rx then
        --- @type boolean, string|distant.core.server.Details|nil
        local success, details = pcall(rx)
        if success then
            --- @cast details -string
            return nil, details
        else
            --- @cast details -distant.core.server.Details
            return details
        end
    end
end

--- Returns whether or not the server is running.
--- @return boolean
function M:is_running()
    return self.handle ~= nil and self.handle:running()
end

--- Kills the server if it is running.
function M:kill()
    if self.handle ~= nil then
        self.handle:stop()
        self.handle = nil
    end
end

return M
