local editor = require('distant.editor')
local fn     = require('distant.fn')
local log    = require('distant-core').log
local utils  = require('distant-core').utils
local vars   = require('distant-core').vars

--- @class distant.nav.Actions
local M      = {}

--- Returns the separator used by the remote system
--- @return string
local function remote_sep()
    local err, system_info = fn.cached_system_info({})
    assert(not err, tostring(err))
    assert(system_info, 'Missing system info')
    return assert(system_info.main_separator, 'missing remote sep')
end

--- Returns the path under the cursor without joining it to the base path
--- @return string
local function path_under_cursor()
    local linenr = vim.fn.line('.') - 1
    return vim.api.nvim_buf_get_lines(0, linenr, linenr + 1, true)[1]
end

--- Returns the full path under cursor by joining it with the base path
--- @return string|nil
local function full_path_under_cursor()
    local base_path = vars.buf().remote_path:get()
    if base_path ~= nil then
        return utils.join_path(remote_sep(), { base_path, path_under_cursor() })
    end
end

--- Opens the selected item to be edited
---
--- 1. In the case of a file, it is loaded into a buffer
--- 2. In the case of a directory, the navigator enters it
---
--- @param opts? {bufnr?:number, winnr?:number, line?:number, col?:number, reload?:number, timeout?:number, interval?:number}
M.edit = function(opts)
    opts = opts or {}

    local path = full_path_under_cursor()
    if path ~= nil then
        editor.open(vim.tbl_deep_extend('keep', { path = path }, opts))
    end
end

--- Moves up to the parent directory of the current file or directory
---
--- ### Options
---
--- * reload: If provided, overrides the default (default: true)
---
--- @param opts? {reload?:boolean}
M.up = function(opts)
    opts = opts or {}

    local base_path = vars.buf().remote_path:get()
    local reload = true
    if opts.reload ~= nil then
        reload = opts.reload
    end

    if base_path ~= nil then
        local parent = utils.parent_path(base_path)
        if parent ~= nil then
            editor.open({ path = parent, reload = reload })
        end
    end
end

--- Creates a new file in the current directory
---
--- ### Options
---
--- * path: If provided, is used as new file path joined to current directory
---
--- @param opts? {path?:string}
M.newfile = function(opts)
    opts = opts or {}

    local base_path = vars.buf().remote_path:get()
    if base_path ~= nil then
        local name = opts.path or vim.fn.input('Name: ')
        if name == '' then
            return
        end

        local path = utils.join_path(remote_sep(), { base_path, name })
        editor.open(path)
    end
end

--- Creates a directory within the current directory (fails if file)
---
--- ### Options
---
--- * path: If provided, is used as new directory path joined to current directory
---
--- @param opts? {path?:string}
M.mkdir = function(opts)
    opts = opts or {}

    local base_path = vars.buf().remote_path:get()
    if base_path ~= nil then
        local name = opts.path or vim.fn.input('Directory name: ')
        if name == '' then
            return
        end

        local path = utils.join_path(remote_sep(), { base_path, name })
        local err = fn.create_dir({ path = path, all = true })

        if not err then
            editor.open({ path = base_path, reload = true })
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
--- @param opts? {path?:string}
M.rename = function(opts)
    opts = opts or {}

    local base_path = vars.buf().remote_path:get()
    if base_path ~= nil then
        local old_path = full_path_under_cursor()
        if old_path ~= nil then
            --- @diagnostic disable-next-line:redundant-parameter
            local new_path = opts.path or vim.fn.input('New name: ', old_path)
            if new_path == '' then
                return
            end

            local err = fn.rename({ src = old_path, dst = new_path })

            if not err then
                editor.open({ path = base_path, reload = true })
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
--- @param opts? {force?:boolean, no_prompt?:boolean, timeout?:number, interval?:number}
M.remove = function(opts)
    opts = opts or {}

    local base_path = vars.buf().remote_path:get()
    if base_path ~= nil then
        local path = full_path_under_cursor()
        if path ~= nil then
            -- Unless told not to show, we always prompt when deleting
            if not opts.no_prompt then
                if vim.fn.confirm("Delete?: " .. path_under_cursor(), "&Yes\n&No", 1) ~= 1 then
                    return
                end
            end

            local err = fn.remove(vim.tbl_extend('keep', { path = path }, opts))

            if not err then
                editor.open({ path = base_path, reload = true })
            else
                log.error(string.format('Failed to remove %s: %s', path, err))
            end
        end
    end
end

return M
