local editor = require('distant.editor')
local log    = require('distant-core').log
local plugin = require('distant')
local utils  = require('distant-core').utils

--- @class distant.nav.Actions
local M      = {}

--- Returns the separator used by the remote system
--- @param client_id? distant.core.manager.ConnectionId
--- @return string
local function remote_sep(client_id)
    local err, system_info = plugin.api(client_id).cached_system_info({})
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
--- @param client_id? distant.core.manager.ConnectionId
--- @return string|nil
local function full_path_under_cursor(client_id)
    local base_path = plugin.buf.path()
    if base_path ~= nil then
        return utils.join_path(remote_sep(client_id), { base_path, path_under_cursor() })
    end
end

--- Opens the selected item to be edited
---
--- 1. In the case of a file, it is loaded into a buffer
--- 2. In the case of a directory, the navigator enters it
---
--- @param opts? {bufnr?:number, winnr?:number, line?:number, col?:number, reload?:boolean, timeout?:number, interval?:number}
M.edit = function(opts)
    opts = opts or {}

    local client_id = plugin.buf.client_id()
    local path = full_path_under_cursor(client_id)
    if path ~= nil then
        editor.open({
            client_id = client_id,
            path = path,
            bufnr = opts.bufnr,
            line = opts.line,
            col = opts.col,
            reload = opts.reload,
            winnr = opts.winnr,
            timeout = opts.timeout,
            interval = opts.interval,
        })
    end
end

--- Displays metadata for the path under the cursor.
M.metadata = function()
    local client_id = plugin.buf.client_id()
    local path = full_path_under_cursor(client_id)
    if path ~= nil then
        editor.show_metadata({ path = path })
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

    local client_id = plugin.buf.client_id()
    local base_path = plugin.buf.path()
    local reload = true
    if opts.reload ~= nil then
        reload = opts.reload
    end

    if base_path ~= nil then
        local parent = utils.parent_path(base_path)
        if parent ~= nil then
            editor.open({
                path = parent,
                reload = reload,
                client_id = client_id,
            })
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

    local client_id = plugin.buf.client_id()
    local base_path = plugin.buf.path()
    if base_path ~= nil then
        local name = opts.path or vim.fn.input('Name: ')
        if name == '' then
            return
        end

        local path = utils.join_path(remote_sep(client_id), { base_path, name })
        editor.open({
            path = path,
            client_id = client_id,
        })
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

    local client_id = plugin.buf.client_id()
    local base_path = plugin.buf.path()
    if base_path ~= nil then
        local name = opts.path or vim.fn.input('Directory name: ')
        if name == '' then
            return
        end

        local path = utils.join_path(remote_sep(client_id), { base_path, name })
        local err = plugin.api(client_id).create_dir({ path = path, all = true })

        if not err then
            editor.open({
                client_id = client_id,
                path = base_path,
                reload = true,
            })
        else
            log.error(string.format('Failed to create %s: %s', path, err))
        end
    end
end

--- Copies a file or directory within the current directory
---
--- ### Options
---
--- * path: If provided, is used as new directory path joined to current directory
---
--- @param opts? {path?:string}
M.copy = function(opts)
    opts = opts or {}

    local client_id = plugin.buf.client_id()
    local base_path = plugin.buf.path()
    if base_path ~= nil then
        local src_path = full_path_under_cursor(client_id)
        if src_path ~= nil then
            --- @diagnostic disable-next-line:redundant-parameter
            local dst_path = opts.path or vim.fn.input('Copy name: ', src_path)
            if dst_path == '' then
                return
            end

            local err = plugin.api(client_id).copy({ src = src_path, dst = dst_path })

            if not err then
                editor.open({
                    client_id = client_id,
                    path = base_path,
                    reload = true,
                })
            else
                log.error(string.format('Failed to rename %s to %s: %s', src_path, dst_path, err))
            end
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

    local client_id = plugin.buf.client_id()
    local base_path = plugin.buf.path()
    if base_path ~= nil then
        local old_path = full_path_under_cursor(client_id)
        if old_path ~= nil then
            --- @diagnostic disable-next-line:redundant-parameter
            local new_path = opts.path or vim.fn.input('New name: ', old_path)
            if new_path == '' then
                return
            end

            local err = plugin.api(client_id).rename({ src = old_path, dst = new_path })

            if not err then
                editor.open({
                    client_id = client_id,
                    path = base_path,
                    reload = true,
                })
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

    local client_id = plugin.buf.client_id()
    local base_path = plugin.buf.path()
    if base_path ~= nil then
        local path = full_path_under_cursor(client_id)
        if path ~= nil then
            -- Do not force by default
            local force = false

            -- Unless told not to show, we always prompt when deleting
            if not opts.no_prompt then
                local choice = vim.fn.confirm("Delete?: " .. path_under_cursor(), "&Yes\n&Force\n&No", 1)

                -- 0 is cancel, 3 is no
                if choice == 0 or choice == 3 then
                    return
                end

                -- 2 is force
                force = choice == 2
            end

            local err = plugin.api(client_id).remove({
                path = path,
                force = force,
                timeout = opts.timeout,
                interval = opts.interval,
            })

            if not err then
                editor.open({
                    client_id = client_id,
                    path = base_path,
                    reload = true
                })
            else
                log.fmt_error('Failed to remove %s: %s', path, tostring(err))
            end
        end
    end
end

return M
