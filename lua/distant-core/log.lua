-- log.lua
--
-- Inspired by rxi/log.lua
-- Modified by tjdevries and can be found at github.com/tjdevries/vlog.nvim
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.

--- @alias neovim.log.Level 'trace'|'debug'|'info'|'warn'|'error'|'off'

--- @type neovim.log.Level
local d_log_level = vim.fn.getenv('DISTANT_LOG_LEVEL')
if d_log_level == vim.NIL then
    d_log_level = 'info'
end

--- @type string|nil
local d_log_file = vim.fn.getenv('DISTANT_LOG_FILE')
if d_log_file == vim.NIL then
    d_log_file = nil
end

-- User configuration section
local default_config = {
    -- Name of the plugin. Prepended to log messages
    plugin = 'distant',
    -- Should print the output to neovim while running
    -- values: 'sync','async',false
    use_console = 'async',
    -- Should highlighting be used in console (using echohl)
    highlights = true,
    -- Should write to a file
    use_file = true,
    -- Any messages above this level will be logged.
    level = string.lower(d_log_level),
    -- Level configuration
    modes = {
        { name = 'trace', hl = 'Comment' },
        { name = 'debug', hl = 'Comment' },
        { name = 'info',  hl = 'None' },
        { name = 'warn',  hl = 'WarningMsg' },
        { name = 'error', hl = 'ErrorMsg' },

        -- This should always be last and is used to disable logging
        { name = 'off',   hl = 'None' },
    },
    -- Can limit the number of decimals displayed for floats
    float_precision = 0.01,
}

--- @class distant.core.Logger
--- @field outfile string # path to the file where the log is written
---
--- @field trace fun(...)
--- @field fmt_trace fun(...)
--- @field lazy_trace fun(f:fun())
--- @field file_trace fun(vals:table, override:{info_level:integer})
---
--- @field debug fun(...)
--- @field fmt_debug fun(...)
--- @field lazy_debug fun(f:fun())
--- @field file_debug fun(vals:table, override:{info_level:integer})
---
--- @field info fun(...)
--- @field fmt_info fun(...)
--- @field lazy_info fun(f:fun())
--- @field file_info fun(vals:table, override:{info_level:integer})
---
--- @field warn fun(...)
--- @field fmt_warn fun(...)
--- @field lazy_warn fun(f:fun())
--- @field file_warn fun(vals:table, override:{info_level:integer})
---
--- @field error fun(...)
--- @field fmt_error fun(...)
--- @field lazy_error fun(f:fun())
--- @field file_error fun(vals:table, override:{info_level:integer})
---
--- @field fatal fun(...)
--- @field fmt_fatal fun(...)
--- @field lazy_fatal fun(f:fun())
--- @field file_fatal fun(vals:table, override:{info_level:integer})
local M = {}

local unpack = unpack or table.unpack

M.new = function(config, standalone)
    config = vim.tbl_deep_extend('force', default_config, config)

    local outfile = d_log_file or
        string.format('%s/%s.log', vim.api.nvim_call_function('stdpath', { 'cache' }), config.plugin)

    local obj
    if standalone then
        obj = M
    else
        obj = config
    end

    local levels = {}
    for i, v in ipairs(config.modes) do
        levels[v.name] = i
    end

    local round = function(x, increment)
        increment = increment or 1
        x = x / increment
        return (x > 0 and math.floor(x + 0.5) or math.ceil(x - 0.5)) * increment
    end

    local make_string = function(...)
        local t = {}
        for i = 1, select('#', ...) do
            local x = select(i, ...)

            if type(x) == 'number' and config.float_precision then
                x = tostring(round(x, config.float_precision))
            elseif type(x) == 'table' then
                x = vim.inspect(x)
            else
                x = tostring(x)
            end

            t[#t + 1] = x
        end
        return table.concat(t, ' ')
    end

    local log_at_level = function(level, level_config, message_maker, ...)
        -- Return early if we're below the config.level
        if level < levels[config.level] then
            return
        end
        local nameupper = level_config.name:upper()

        local success, msg = pcall(message_maker, ...)
        if not success then
            vim.api.nvim_err_writeln('message_maker(' .. vim.inspect({ ... }) .. ')')
            error(msg)
        end
        local info = debug.getinfo(config.info_level or 2, 'Sl')
        local lineinfo = info.short_src .. ':' .. info.currentline

        -- Output to console
        if config.use_console then
            local log_to_console = function()
                local console_string = string.format('[%-6s%s] %s: %s', nameupper, os.date '%H:%M:%S', lineinfo, msg)

                if config.highlights and level_config.hl then
                    vim.cmd(string.format('echohl %s', level_config.hl))
                end

                --- @diagnostic disable-next-line:missing-parameter
                local split_console = vim.split(console_string, '\n')
                for _, v in ipairs(split_console) do
                    local formatted_msg = string.format('[%s] %s', config.plugin, vim.fn.escape(v, [['\]]))

                    --- @diagnostic disable-next-line:param-type-mismatch
                    local ok = pcall(vim.cmd, string.format([[echom '%s']], formatted_msg))
                    if not ok then
                        vim.api.nvim_out_write(msg .. '\n')
                    end
                end

                if config.highlights and level_config.hl then
                    vim.cmd 'echohl NONE'
                end
            end
            if config.use_console == 'sync' and not vim.in_fast_event() then
                log_to_console()
            else
                vim.schedule(log_to_console)
            end
        end

        -- Output to log file
        if config.use_file then
            local fp = assert(io.open(outfile, 'a'))
            local str = string.format('[%-6s%s] %s: %s\n', nameupper, os.date(), lineinfo, msg)
            fp:write(str)
            fp:close()
        end
    end

    for i, x in ipairs(config.modes) do
        if x.name ~= 'off' then
            -- log.info('these', 'are', 'separated')
            --- @diagnostic disable-next-line:assign-type-mismatch
            obj[x.name] = function(...)
                return log_at_level(i, x, make_string, ...)
            end

            -- log.fmt_info('These are %s strings', 'formatted')
            --- @diagnostic disable-next-line:assign-type-mismatch
            obj[('fmt_%s'):format(x.name)] = function(...)
                return log_at_level(i, x, function(...)
                    local passed = { ... }
                    local fmt = table.remove(passed, 1)
                    local inspected = {}
                    for _, v in ipairs(passed) do
                        table.insert(inspected, vim.inspect(v))
                    end
                    return string.format(fmt, unpack(inspected))
                end, ...)
            end

            -- log.lazy_info(expensive_to_calculate)
            --- @diagnostic disable-next-line:assign-type-mismatch
            obj[('lazy_%s'):format(x.name)] = function()
                return log_at_level(i, x, function(f)
                    return f()
                end)
            end

            -- log.file_info('do not print')
            --- @diagnostic disable-next-line:assign-type-mismatch
            obj[('file_%s'):format(x.name)] = function(vals, override)
                local original_console = config.use_console
                config.use_console = false
                config.info_level = override.info_level
                log_at_level(i, x, make_string, unpack(vals))
                config.use_console = original_console
                config.info_level = nil
            end
        end
    end

    --- Represents where log is being written
    obj.outfile = outfile

    return obj
end

M.new(default_config, true)
-- }}}

return M
