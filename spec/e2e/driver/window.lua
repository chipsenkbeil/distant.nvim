--- @class spec.e2e.Window
--- @field private __driver spec.e2e.Driver
--- @field private __id  number
local M = {}
M.__index = M

--- Creates a new instance of a reference to a local file.
--- @param opts {driver:spec.e2e.Driver, id:number}
--- @return spec.e2e.Window
function M:new(opts)
    local instance = {}
    setmetatable(instance, M)
    instance.__driver = assert(opts.driver, 'Missing driver')
    instance.__id = assert(opts.id, 'Missing id')
    return instance
end

--- Returns window id.
--- @return number
function M:id()
    return self.__id
end

--- Returns id of buffer attached to window.
--- @return number
function M:buf()
    return vim.api.nvim_win_get_buf(self.__id)
end

--- Places the specific buffer in this window.
--- @param buf number
function M:set_buf(buf)
    vim.api.nvim_win_set_buf(self.__id, buf)
end

--- Moves the cursor to the current line in the window.
--- @param line number #(1-based index)
function M:move_cursor_to_line(line)
    assert(line ~= 0, 'line is 1-based index')
    vim.api.nvim_win_set_cursor(self.__id, { line, 0 })
end

--- Moves cursor to line and column where first match is found
--- for the given pattern.
---
--- @param p string #pattern to match against
--- @param opts? {line_only?:boolean}
--- @return number? line, number? col #The line and column position, or nil if no movement
function M:move_cursor_to(p, opts)
    opts = opts or {}
    assert(type(p) == 'string', 'pattern must be a string')
    local lines = self.__driver:buffer(self:buf()):lines()

    for ln, line in ipairs(lines) do
        local start = string.find(line, p)
        if start ~= nil then
            local col = start - 1
            if opts.line_only then
                col = 0
            end

            vim.api.nvim_win_set_cursor(self.__id, { ln, col })
            return ln, col
        end
    end
end

--- Returns the line number (1-based index) of the cursor's position.
--- @return number line #(1-based index)
function M:cursor_line_number()
    return vim.api.nvim_win_get_cursor(self.__id)[1]
end

--- Retrieves content at line where cursor is
--- @return string
function M:line_at_cursor()
    local ln = self:cursor_line_number() - 1
    return vim.api.nvim_buf_get_lines(
        self:buf(),
        ln,
        ln + 1,
        true
    )[1]
end

return M
