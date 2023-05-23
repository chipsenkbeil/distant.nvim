--- Represents a generic timeout data structure.
--- @class distant.core.Timeout
--- @field max integer # Maximimum time to wait (in milliseconds)
--- @field interval integer # Time to wait (in milliseconds) inbetween checks to see if timeout has been reached
local M = {}
M.__index = M

--- Creates a new timeout.
---
--- * If `opts` is an integer, it is used as the `max` value.
--- * If `opts` is a table, `opts.max` is used with `opts.interval` optional.
--- * If no interval is specified, it will be calculated based on `max`.
---
--- @param opts integer|{max:integer, interval?:integer}
--- @return distant.core.Timeout
function M:new(opts)
    local instance = {}
    setmetatable(instance, M)

    --- @type integer, integer
    local max, interval

    if type(opts) == 'number' then
        max = opts
    elseif type(opts) == 'table' then
        max = opts.max
        interval = opts.interval
    end

    assert(
        type(max) == 'number',
        string.format('Invalid timeout.max, expected integer, got %s', vim.inspect(max))
    )

    if interval == nil then
        -- Set interval to 1/10th of the max with minimum being 1ms
        interval = math.max(math.floor(max / 10.0), 1)
    end

    assert(
        type(interval) == 'number',
        string.format('Invalid timeout.interval, expected integer, got %s', vim.inspect(interval))
    )

    instance.max = max
    instance.interval = interval

    return instance
end

--- Waits for a condition, otherwise the timeout error is thrown.
--- @param cond fun():boolean
--- @param fast_only? boolean
function M:wait(cond, fast_only)
    local ok, code = vim.wait(self.max, cond, self.interval, fast_only)
    if not ok and code == -1 then
        error('Timeout reached ' .. self.max .. 'ms!')
    elseif not ok and code == -2 then
        error('Timeout interrupted!')
    end
end

--- Tries to wait for a condition. If successful, returns true, otherwise false.
---
--- @param cond fun():boolean
--- @param fast_only? boolean
--- @return boolean
function M:try_wait(cond, fast_only)
    local ok, _ = pcall(self.wait, self, cond, fast_only)
    return ok
end

return M
