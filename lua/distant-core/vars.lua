local Buffer = require('distant-core.vars.buffer')
local utils = require('distant-core.utils')

-- GLOBAL DEFINITIONS ---------------------------------------------------------

--- @class distant.core.Vars
local M = {}
M.__index = M

-- BUF LOCAL DEFINITIONS ------------------------------------------------------

--- @param path string
--- @return string
local function remove_trailing_slash(path)
    local s, _ = string.gsub(path, '[\\/]+$', '')
    return s
end

--- @param bufnr? number
--- @return distant.core.vars.Buffer
function M.buf(bufnr)
    return Buffer:new({ buf = bufnr or 0 })
end

--- Search all buffers for path or alt path match
--- @param path string #looks for distant://path and path itself
--- @return number|nil #handle of buffer of first match if found
function M.find_buf_with_path(path)
    if type(path) ~= 'string' then
        return
    end

    -- Simplify the path we are searching for to be the local
    -- portion without a trailing slash or distant:// scheme
    path = utils.strip_prefix(path, 'distant://')
    path = remove_trailing_slash(path)

    -- Check if we have a buffer in the form of distant://path
    local bufnr = vim.fn.bufnr('^distant://' .. path .. '$', 0)
    if bufnr ~= -1 then
        return bufnr
    end

    -- Otherwise, we look through all buffers to see if the path is set
    -- as the primary or one of the alternate paths
    --- @diagnostic disable-next-line:redefined-local
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if Buffer:new({ buf = bufnr }):has_matching_remote_path(path) then
            return bufnr
        end
    end
end

return M
