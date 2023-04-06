local log = require('distant-core.log')
local settings = require('distant-core.settings')
local utils = require('distant-core.utils')

--- @class EditorSearchState
--- @field qfid number #id of quickfix list storing results
--- @field searcher DistantSearcher #searcher being used

--- @class State
--- @field client Client|nil #active client
--- @field manager Manager|nil #active manager
--- @field search EditorSearchState|nil #active search via editor
--- @field settings Settings #user settings
local State = {}
State.__index = State

--- @return State
function State:new()
    local instance = {}
    setmetatable(instance, State)
    instance.client = nil
    instance.manager = nil
    instance.search = nil

    -- Set default settings so we don't get nil access errors even when no
    -- launch call has been made yet
    instance.settings = settings.default()

    return instance
end

--- Loads into state the settings appropriate for the remote machine with the give label
--- @param destination string Full destination to server, which can be in a form like SCHEME://USER:PASSWORD@HOST:PORT
--- @return Settings
function State:load_settings(destination)
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

--- Loads the manager using the specified config, installing the underlying cli if necessary
--- @overload fun(opts:ManagerConfig):Manager
--- @param opts ManagerConfig
--- @param cb fun(err:string|nil, manager:Manager|nil) #if provided, will asynchronously return manager
--- @return Manager|nil #if synchronous, returns manager
function State:load_manager(opts, cb)
    local rx
    if not cb then
        cb, rx = utils.oneshot_channel(
            self.settings.max_timeout,
            self.settings.timeout_interval
        )
    end

    if not self.manager then
        -- NOTE: Lazily load cli to prevent loop
        local cli = require('distant.cli')

        cli.install(opts, function(err, path)
            if err then
                return cb(err)
            end

            -- Define manager using provided opts, overriding the default network settings
            self.manager = cli.manager(vim.tbl_extend('keep', opts, {
                binary = path,
                -- Create a neovim-local manager network setting as default
                network = {
                    windows_pipe = 'nvim-' .. utils.next_id(),
                    unix_socket = utils.cache_path('nvim-' .. utils.next_id() .. '.sock'),
                },
            }))

            if not self.manager:is_listening({}) then
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

function State:launch(opts, cb)
    assert(opts.destination, 'Destination is missing')

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

function State:connect(opts, cb)
    assert(opts.destination, 'Destination is missing')

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

local GLOBAL_STATE = State:new()
return GLOBAL_STATE
