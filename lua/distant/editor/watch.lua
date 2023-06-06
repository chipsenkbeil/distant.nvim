local plugin = require('distant')
local Error = require('distant-core.api.error')

--- @param bufnr number
--- @param retry_interval number
local function do_watch(bufnr, retry_interval)
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
                if vim.api.nvim_buf_is_valid(bufnr) then
                    vim.defer_fn(function()
                        do_watch(bufnr, retry_interval)
                    end, retry_interval)
                end
            else
                vim.notify(tostring(err), vim.log.levels.ERROR)
            end

            return
        end

        -- Otherwise, should have a watcher we can use
        assert(watcher):on_change(function(change)
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
            --         ii.  If modified and buffer changed, print msg "W12: Warning: File \"%s\" has changed and the buffer was changed in Vim as well"
            --         iii. If modified, print msg "W11: Warning: File \"%s\" has changed since editing started"
            --         iv.  If mode changed, print "W16: Warning: Mode of file \"%s\" has changed since editing started"
            --         v.   If only timestamp changed (e.g. CSV), don't report anything
            -- 2. For file created that matches a buffer, show warning and mark reload possible
            -- 3. If reload is possible (file not deleted), present a prompt, "&OK\n&Load File\nLoad File &and Options"
            --     a. If OK selected, `reload` is NONE
            --     b. If Load File selected, `reload` is NORMAL
            --     c. If Load File and Options selected, `reload` is DETECT
            -- 4. Trigger a buf_reload
            --     a. If `reload` is NORMAL, just reload the text
            --     b. If `reload` is DETECT, reset syntax highlighting/clear marks/diff status/etc; force fileformat and encoding
            -- 5. Undo file is unusable and overwritten
            local buf_modified = vim.bo[bufnr].modified

            --- @type 'conflict'|'changed'|'deleted'|''
            local reason =
                ((change.kind == 'access' or change.kind == 'modify') and (buf_modified and 'conflict' or 'changed'))
                or (change.kind == 'delete' and 'deleted')
                or ''

            --- @type 'none'|'normal'|'detect'
            local reload = 'none'
            local prompt_reload = false
            if reason ~= '' then
                --- @diagnostic disable-next-line:undefined-field
                if vim.go.autoread and reason == 'changed' then
                    reload = 'normal'
                else
                    local skip_msg = false
                    local autocmds = vim.api.nvim_get_autocmds({
                        event = { 'FileChangedShell' },
                        pattern = require('distant.autocmd').pattern(),
                    })

                    -- Invoke FileChangedShell autocommands if we have them
                    if not vim.tbl_isempty(autocmds) then
                        vim.v.fcs_reason = reason
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
                            vim.notify(('E211: File "%s" no longer available'):format(bufname), vim.log.levels.ERROR)
                        else
                            prompt_reload = true

                            if reason == 'conflict' then
                                vim.notify(
                                    ('W12: Warning: File "%s" has changed and the buffer was changed in Vim as well')
                                    :format(bufname),
                                    vim.log.levels.WARN
                                )
                            end
                        end
                    end
                end
            end

            if prompt_reload then
                vim.ui.input({
                    prompt = '[O]K, (L)oad File, Load File (a)nd Options:'
                }, function(input)
                    if input == 'L' or input == 'l' then
                        reload = 'normal'
                    elseif input == 'A' or input == 'a' then
                        reload = 'detect'
                    else
                        reload = 'none'
                    end

                    if reload ~= 'none' then
                        -- TODO: Support detect mode
                        vim.api.nvim_exec_autocmds('BufReadCmd', {
                            group = 'distant',
                            pattern = bufname,
                        })
                    end
                end)
            elseif reload ~= 'none' then
                -- TODO: Support detect mode
                vim.api.nvim_exec_autocmds('BufReadCmd', {
                    group = 'distant',
                    pattern = bufname,
                })
            end
        end)
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
    do_watch(bufnr, opts.retry_interval or plugin.settings.buffer.watch_retry_timeout)
end
