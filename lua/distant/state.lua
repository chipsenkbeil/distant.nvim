local Cli         = require('distant-core').Cli
local log         = require('distant-core').log
local Manager     = require('distant-core').Manager
local min_version = require('distant.version').minimum
local settings    = require('distant-core').settings
local utils       = require('distant-core').utils

--- @class State
--- @field client? DistantClient #active client
--- @field manager? DistantManager #active manager
--- @field active_search {qfid?:number, searcher?:DistantApiSearcher} #active search via editor
--- @field settings DistantSettings #user settings
local M           = {}
M.__index         = M

--- @return State
function M:new()
    local instance = {}
    setmetatable(instance, M)
    instance.client = nil
    instance.manager = nil
    instance.active_search = {}

    -- Set default settings so we don't get nil access errors even when no
    -- launch call has been made yet
    instance.settings = settings.default()

    return instance
end

--- Loads into state the settings appropriate for the remote machine with the give label
--- @param destination string Full destination to server, which can be in a form like SCHEME://USER:PASSWORD@HOST:PORT
--- @return DistantSettings
function M:load_settings(destination)
    log.fmt_trace('Detecting settings for destination: %s', destination)

    -- Parse our destination into the host only
    local label
    local d = utils.parse_destination(destination)
    if not d or not d.host then
        error('Invalid destination: ' .. tostring(destination))
    else
        label = d.host
        log.fmt_debug('Using settings label: %s', label)
    end

    self.settings = settings.for_label(label)
    log.fmt_debug('Settings loaded: %s', self.settings)

    return self.settings
end

--- Loads the manager using the specified config, installing the underlying cli if necessary.
--- @param opts {bin:string, network?:DistantManagerNetwork, timeout?:number, interval?:number}
--- @param cb? fun(err?:string, manager?:DistantManager)
--- @return string|nil, DistantManager|nil
function M:load_manager(opts, cb)
    assert(opts.bin, 'Bin is missing')

    local rx
    if not cb then
        cb, rx = utils.oneshot_channel(
            self.settings.max_timeout,
            self.settings.timeout_interval
        )
    end

    if not self.manager then
        Cli:new({ bin = opts.bin }):install({ min_version = min_version }, function(err, path)
            if err then
                return cb(err)
            end

            -- Define manager using provided opts, overriding the default network settings
            self.manager = Manager:new(vim.tbl_extend('keep', opts, {
                binary = path,
                -- Create a neovim-local manager network setting as default
                network = {
                    windows_pipe = 'nvim-' .. utils.next_id(),
                    unix_socket = utils.cache_path('nvim-' .. utils.next_id() .. '.sock'),
                },
            }))

            local is_listening = self.manager:is_listening({
                timeout = opts.timeout,
                interval = opts.interval,
            })
            if not is_listening then
                log.debug('Manager not listening, so starting process')

                --- @diagnostic disable-next-line:redefined-local
                self.manager:listen({}, function(err)
                    if err then
                        log.fmt_error('Manager failed: %s', err)
                    end
                end)

                if not self.manager:wait_for_listening({}) then
                    log.error('Manager still does not appear to be listening')
                end
            end

            return cb(nil, self.manager)
        end)
    else
        cb(nil, self.manager)
    end

    -- If we have a receiver, this indicates that we are synchronous
    if rx then
        local err1, err2, result = rx()
        return err1 or err2, result
    end
end

--- Launches a remote server and connects to it.
--- @param opts {destination:string, bin:string, network?:DistantManagerNetwork, timeout?:number, interval?:number}
--- @param cb fun(err?:string, client?:DistantClient)
function M:launch(opts, cb)
    assert(opts.destination, 'Destination is missing')
    assert(opts.bin, 'Bin is missing')

    self:load_manager(opts, function(err, manager)
        if err then
            return cb(err)
        end

        assert(manager, 'Impossible: manager is nil')

        --- @diagnostic disable-next-line:redefined-local
        manager:launch(opts, function(err, client)
            if client then
                self.client = client
            end

            return cb(err, client)
        end)
    end)
end

--- Connects to a remote server.
--- @param opts {destination:string, bin:string, network?:DistantManagerNetwork, timeout?:number, interval?:number}
--- @param cb fun(err?:string, client?:DistantClient)
function M:connect(opts, cb)
    assert(opts.destination, 'Destination is missing')
    assert(opts.bin, 'Bin is missing')

    self:load_manager(opts, function(err, manager)
        if err then
            return cb(err)
        end

        assert(manager, 'Impossible: manager is nil')

        --- @diagnostic disable-next-line:redefined-local
        manager:connect(opts, function(err, client)
            if client then
                self.client = client
            end

            return cb(err, client)
        end)
    end)
end

local GLOBAL_STATE = M:new()
return GLOBAL_STATE
