local editor = require('distant.editor')
local log = require('distant.log')
local fn = require('distant.fn')
local u = require('distant.utils')
local v = require('distant.vars')

local actions = {}

--- Returns the path under the cursor without joining it to the base path
local function path_under_cursor()
    local linenr = vim.fn.line('.') - 1
    return vim.api.nvim_buf_get_lines(0, linenr, linenr + 1, true)[1]
end

--- Returns the full path under cursor by joining it with the base path
local function full_path_under_cursor()
    local base_path = v.buf.remote_path()
    if base_path ~= nil then
        return u.join_path(base_path, path_under_cursor())
    end
end

--- Wraps an action such that it is performed if the buffer is remote,
--- otherwise the else condition is performed
actions.if_remote = function(if_f, else_f)
    return function(...)
        if v.buf.remote_path() then
            if type(if_f) == 'function' then
                if_f(...)
            end
        else
            if type(else_f) == 'function' then
                else_f(...)
            end
        end
    end
end

--- Opens the selected item to be edited
---
--- 1. In the case of a file, it is loaded into a buffer
--- 2. In the case of a directory, the navigator enters it
actions.edit = function()
    local path = full_path_under_cursor()
    if path ~= nil then
        editor.open(path)
    end
end

--- Moves up to the parent directory of the current file or directory
actions.up = function()
    local base_path = v.buf.remote_path()
    if base_path ~= nil then
        local parent = u.parent_path(base_path)
        if parent ~= nil then
            editor.open({path = parent, reload = true})
        end
    end
end

--- Creates a new file in the current directory
---
--- ### Options
---
--- * path: If provided, is used as new file path joined to current directory
---
--- @param opts table
actions.newfile = function(opts)
    opts = opts or {}

    local base_path = v.buf.remote_path()
    if base_path ~= nil then
        local name = opts.path or vim.fn.input('Name: ')
        if name == '' then
            return
        end

        local path = u.join_path(base_path, name)
        editor.open(path)
    end
end

--- Creates a directory within the current directory (fails if file)
---
--- ### Options
---
--- * path: If provided, is used as new directory path joined to current directory
---
--- @param opts table
actions.mkdir = function(opts)
    opts = opts or {}

    local base_path = v.buf.remote_path()
    if base_path ~= nil then
        local name = opts.path or vim.fn.input('Directory name: ')
        if name == '' then
            return
        end

        local path = u.join_path(base_path, name)
        local err = fn.create_dir({path = path, all = true})

        if not err then
            editor.open({path = base_path, reload = true})
        else
            log.error(string.format('Failed to create %s: %s', path, err))
        end
    end
end

--- Renames a file or directory within the current directory
---
--- ### Options
---
--- * path: If provided, is used as new directory path joined to current directory
---
--- @param opts table
actions.rename = function(opts)
    opts = opts or {}

    local base_path = v.buf.remote_path()
    if base_path ~= nil then
        local old_path = full_path_under_cursor()
        if old_path ~= nil then
            local new_path = opts.path or vim.fn.input('New name: ', old_path)
            if new_path == '' then
                return
            end

            local err = fn.rename({src = old_path, dst = new_path})

            if not err then
                editor.open({path = base_path, reload = true})
            else
                log.error(string.format('Failed to rename %s to %s: %s', old_path, new_path, err))
            end
        end
    end
end

--- Removes a file or directory within the current directory
---
--- ### Options
---
--- * force: If true, will remove directories that are not empty
--- * no_prompt: If true, will not prompt to delete current file/directory
---
--- @param opts table
actions.remove = function(opts)
    opts = opts or {}

    local base_path = v.buf.remote_path()
    if base_path ~= nil then
        local path = full_path_under_cursor()
        if path ~= nil then
            -- Unless told not to show, we always prompt when deleting
            if not opts.no_prompt then
                if vim.fn.confirm("Delete?: " .. path_under_cursor(), "&Yes\n&No", 1) ~= 1 then
                    return
                end
            end

            local err = fn.remove(vim.tbl_extend('keep', {path = path}, opts))

            if not err then
                editor.open({path = base_path, reload = true})
            else
                log.error(string.format('Failed to remove %s: %s', path, err))
            end
        end
    end
end

return actions
