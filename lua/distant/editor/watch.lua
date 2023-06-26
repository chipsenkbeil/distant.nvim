local Error  = require('distant-core.api.error')
local log    = require('distant-core.log')
local plugin = require('distant')

local function start_warning_hl()
    vim.cmd([[echohl WarningMsg]])
end

local function clear_warning_hl()
    vim.cmd([[echohl NONE]])
end

local function print_warning(...)
    vim.api.nvim_echo(vim.tbl_map(function(arg)
        return { tostring(arg), 'WarningMsg' }
    end, { ... }), false, {})
end

--- @param bufnr number
--- @param bufname string
local function make_on_change(bufnr, bufname)
    --- @param change distant.core.api.watch.Change
    return function(change)
        -- Logic for file change via `checktime` (buf_check_timestamp) from neovim
        --
        -- 1. For file change via modification, timestamp, mode:
        --     a. If `autoread` is set, buffer has no changes, and file exists, `reload` is NORMAL
        --     b. If FileChangedShell autocommand exists, invoke it after setting v:fcs_reason and v:fcs_choice
        --         i.   Check if buffer no longer exists, and print "E246: FileChangedShell autocommand deleted buffer"
        --         ii.  If v:fcs_choice == reload and file not deleted, `reload` is NORMAL
        --         iii. If v:fcs_choice == edit, `reload` is DETECT
        --         iv.  If v:fcs_choice == ask, proceed to step c (as if FileChangedShell did not exist)
        --         v.   If v:fcs_choice is nothing, do nothing (stop steps) and let autocmd do everything
        --     c. If there was no FileChangedShell autocommand, enter manual warning (detect using nvim_get_autocmds())
        --         i.   If deleted, just print out file deleted (reload is not possible)
        --         ii.  If modified and buffer changed, mark reload possible
        --         iii. If modified, mark reload possible
        --         iv.  If mode changed, mark reload possible
        --         v.   If only timestamp changed (e.g. CSV), don't report anything, but mark reload possible
        -- 2. For file created that matches a buffer, show warning and mark reload possible
        -- 3. If reload is possible (file not deleted), present a prompt
        --     a. If OK selected, `reload` is NONE
        --     b. If Load File selected, `reload` is NORMAL
        --     c. If Load File and Options selected, `reload` is DETECT
        -- 4. Trigger a buf_reload
        --     a. If `reload` is NORMAL, just reload the text
        --     b. If `reload` is DETECT, reset syntax highlighting/clear marks/diff status/etc; force fileformat and encoding
        -- 5. Undo file is unusable and overwritten
        local buf_modified = vim.bo[bufnr].modified
        local details = change.details or {}
        local attribute = details.attribute

        --- @type 'conflict'|'changed'|'created'|'deleted'|'mode'|'time'|''
        local reason = ''
        if change.kind == 'delete' then
            reason = 'deleted'
        elseif change.kind == 'create' then
            reason = 'created'
        elseif change.kind == 'modify' and buf_modified then
            reason = 'conflict'
        elseif change.kind == 'modify' then
            reason = 'changed'
        elseif change.kind == 'attribute' and (attribute == 'ownership' or attribute == 'permissions') then
            reason = 'mode'
        elseif change.kind == 'attribute' and attribute == 'timestamp' then
            reason = 'time'
        end

        -- If our change kind is opening or closing a file, we ignore it in favor of other events
        if change.kind == 'open' or change.kind == 'close_write' or change.kind == 'close_no_write' then
            return
        end

        -- Ignore any change during buffer locked watch state (file being written)
        -- or when the timestamp itself has not changed but our reason is related
        -- to modification or timestamp changes
        local watched = plugin.buf(bufnr).watched()
        local timestamp = details.timestamp
        if watched == 'locked' or (
            timestamp ~= nil and timestamp == plugin.buf(bufnr).mtime() and
            (reason == '' or reason == 'conflict' or reason == 'changed' or reason == 'time')
            ) then
            return
        end

        -- If we have a timestamp, update our buffer's copy
        if timestamp then
            plugin.buf(bufnr).set_mtime(timestamp)
        end

        --- @type 'none'|'normal'|'detect'
        local reload = 'none'
        local prompt_reload = false
        local warning_msg = nil
        if reason ~= '' then
            --- @diagnostic disable-next-line:undefined-field
            if vim.go.autoread and reason == 'changed' then
                reload = 'normal'
            elseif reason == 'created' then
                prompt_reload = true
                warning_msg = (
                    'W13: Warning: File "%s" has been created after editing started'
                    ):format(bufname)
            else
                local skip_msg = false
                local autocmds = vim.api.nvim_get_autocmds({
                    event = { 'FileChangedShell' },
                    pattern = require('distant.autocmd').pattern(),
                })

                -- Invoke FileChangedShell autocommands if we have them
                if not vim.tbl_isempty(autocmds) then
                    vim.v.fcs_reason = reason

                    -- Execute file changed shell for all groups
                    vim.api.nvim_exec_autocmds('FileChangedShell', {
                        pattern = require('distant.autocmd').pattern()
                    })

                    if vim.v.fcs_choice == 'reload' and change.kind ~= 'delete' then
                        reload = 'normal'
                        skip_msg = true
                    elseif vim.v.fcs_choice == 'edit' then
                        reload = 'detect'
                        skip_msg = true
                    elseif vim.v.fcs_choice == 'ask' then
                        prompt_reload = true
                    else
                        -- In this situation, the autocmd should do everything
                        return
                    end
                end

                if not skip_msg then
                    --         i.   If deleted, just print out file deleted (reload is not possible)
                    --         ii.  If modified and buffer changed, print msg "W12: Warning: File \"%s\" has changed and the buffer was changed in Vim as well"
                    --         iii. If modified, print msg "W11: Warning: File \"%s\" has changed since editing started"
                    --         iv.  If mode changed, print "W16: Warning: Mode of file \"%s\" has changed since editing started"
                    --         v.   If only timestamp changed (e.g. CSV), don't report anything
                    if reason == 'delete' then
                        warning_msg = ('E211: File "%s" no longer available'):format(bufname)
                    else
                        prompt_reload = true

                        if reason == 'conflict' then
                            warning_msg = (
                                'W12: Warning: File "%s" has changed and the buffer was changed in Vim as well'
                                ):format(bufname)
                        elseif reason == 'mode' then
                            warning_msg = (
                                'W16: Warning: Mode of file "%s" has changed since editing started'
                                ):format(bufname)
                        end
                    end
                end
            end
        end

        --- @param reload 'none'|'normal'|'detect'
        local function reload_buffer(reload)
            local buffer = plugin.buf.find({ path = change.path })
            if buffer then
                -- NOTE: We do not trigger BufReadCmd and instead invoke
                --       the editor open directly because invoking a BufReadCmd
                --       will potentially set <abuf> to the wrong buffer in
                --       situations where we do not have that buffer currently
                --       selected (e.g. modifying from a shell).
                plugin.editor.open({
                    path = change.path,
                    bufnr = buffer.bufnr(),
                    client_id = buffer.client_id(),
                    -- Prevent changing current window to buffer that is reloaded
                    no_focus = true,
                    -- TODO: Support detect mode
                    reload = true,
                })
            end
        end

        if prompt_reload then
            start_warning_hl()

            local prompt = '[O]K, (L)oad File, Load File (a)nd Options:'
            if warning_msg then
                prompt = warning_msg .. '\n' .. prompt
            end

            vim.ui.input({
                prompt = prompt,
                highlight = function(input)
                    local len = type(input) == 'string' and input:len() or 0
                    return { { 0, len, 'WarningMsg' } }
                end,
            }, function(input)
                if input == 'L' or input == 'l' then
                    reload = 'normal'
                elseif input == 'A' or input == 'a' then
                    reload = 'detect'
                else
                    reload = 'none'
                end

                if reload ~= 'none' then
                    reload_buffer(reload)
                end

                -- Always trigger our post event for all groups
                vim.api.nvim_exec_autocmds('FileChangedShellPost', {
                    pattern = bufname,
                })
            end)

            clear_warning_hl()
        elseif reload ~= 'none' then
            reload_buffer(reload)
        end

        if not prompt_reload then
            if warning_msg then
                print_warning(warning_msg)
            end

            -- Always trigger our post event for all groups
            vim.api.nvim_exec_autocmds('FileChangedShellPost', {
                pattern = bufname,
            })
        end
    end
end

--- @param bufnr number
--- @param retry_interval number
--- @param simulate_created boolean
local function do_watch(bufnr, retry_interval, simulate_created)
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    local buffer = plugin.buf(bufnr)

    -- If buffer is not a remote file, we do not watch it
    local client_id = buffer.client_id()
    local path = buffer.path()
    if not client_id or not path or buffer.type() ~= 'file' then
        return
    end

    -- If buffer is already watched, we do nothing
    if buffer.watched() then
        return
    end

    -- Update our status so we don't do this again
    buffer.set_watched(true)

    -- Attempt to watch the path
    plugin.api(client_id).watch({ path = path }, function(err, watcher)
        -- If failed to watch, reset our status and then handle
        if err then
            buffer.set_watched(false)

            -- If we tried to watch a path that does not exist, this means
            -- that a new distant buffer was created but not yet saved.
            --
            -- In that case, as long as the buffer is still valid, we will
            -- retry the watch attempt at some set interval.
            if err.kind == Error.kinds.not_found then
                if vim.api.nvim_buf_is_valid(bufnr) and retry_interval > 0 then
                    log.fmt_debug(
                        'Unable to watch %s (not found), scheduling retry after %dms',
                        path,
                        retry_interval
                    )
                    vim.defer_fn(function()
                        -- Mark is_new == true so we know that when this succeeds later
                        -- that the buffer needs to be reloaded
                        do_watch(
                            bufnr,
                            retry_interval,
                            true -- simulate created
                        )
                    end, retry_interval)
                end
            else
                vim.notify(tostring(err), vim.log.levels.ERROR)
            end

            return
        end

        -- If this is a newly-created file, we won't get a file creation event because
        -- the watch wasn't successfully registered until AFTER creation (we'd only get
        -- that if we recursively watched a directory); so, we want to simulate a
        -- change event for creation so we can trigger prompts and reloading
        local on_change = make_on_change(bufnr, bufname)
        if simulate_created then
            on_change({
                timestamp = 0, -- Not needed for create event
                kind      = 'create',
                path      = path,
                details   = nil,
            })
        end

        -- Otherwise, should have a watcher we can use
        log.fmt_debug('Watching for changes for %s', path)
        assert(watcher):on_change(on_change)
    end)
end

--- Watches a buffer for changes on the remote machine.
---
--- ### Options
---
--- * `buf` - buffer to watch
--- * `retry_interval` - if watch fails w/ path not found, the time in milliseconds to wait before trying again
---
--- @param opts {buf:number, retry_interval?:number}
return function(opts)
    local bufnr = assert(opts.buf)
    do_watch(
        bufnr,
        opts.retry_interval or plugin.settings.buffer.watch.retry_timeout,
        false -- simulate created
    )
end
