local config = require('spec.unit.config')
local utils = require('distant-core.utils')

local M = {}

--- Creates a pair of functions with one waiting for the other to be called.
--- @return fun() done, fun() wait
function M.make_channel()
    local tx, rx = utils.oneshot_channel(config.timeout, config.timeout_interval)
    local function done()
        tx(true)
    end

    local function wait()
        local ok, result = pcall(rx)
        assert.is.truthy(ok)
        assert.is.truthy(result)
    end

    return done, wait
end

--- @param lines string|string[]
--- @return number
function M.make_buffer(lines)
    local buf = vim.api.nvim_create_buf(true, false)
    if buf == 0 then
        error('Failed to create buffer')
    end

    if type(lines) == 'string' then
        lines = vim.split(lines, '\n', { plain = true })
    end

    vim.api.nvim_buf_set_lines(buf, 1, -1, false, lines)
    return buf
end

return M
