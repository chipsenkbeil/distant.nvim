local log    = require('distant-core').log
local plugin = require('distant')

local mapper = require('distant.editor.open.mapper')

local M      = {}

--- @class distant.editor.open.ConfigureOpts
--- @field bufnr number # number associated with the buffer
--- @field name string #name of the buffer (e.g. distant://path/to/file.txt)
--- @field canonicalized_path string #primary path (e.g. path/to/file.txt)
--- @field raw_path string #raw input path, which could be an alt path
--- @field is_dir boolean #true if buffer represents a directory
--- @field is_file boolean #true if buffer represents a file
--- @field missing boolean
--- @field client_id? distant.core.manager.ConnectionId # id of the client to use
--- @field winnr? number #window number to use

--- @param opts distant.editor.open.ConfigureOpts
function M.configure(opts)
    log.fmt_trace('configurator.configure(%s)', opts)

    local bufnr = opts.bufnr
    local winnr = opts.winnr or 0
    local bufname = opts.name

    --- NOTE: We have to capture the old buffer name and then check
    ---       if setting a new name copies the old buffer name to be
    ---       unlisted. If so, we delete it.
    --- Issue: https://github.com/neovim/neovim/issues/20059
    ---
    --- @diagnostic disable-next-line:redefined-local
    local function set_bufname(bufnr, bufname)
        local old_bufname = vim.api.nvim_buf_get_name(bufnr)
        if old_bufname == bufname then
            log.fmt_debug('Buffer already had this name')
            return
        end

        -- Set the buffer name to include a schema, which will trigger our
        -- autocmd for writing to the remote destination in the situation
        -- where we are editing a file
        vim.api.nvim_buf_set_name(bufnr, bufname)

        -- Look for any buffer that is NOT this one that contains the same
        -- name prior to us setting the new name
        --
        -- If we find a match, this is a bug in neovim (?) and we delete it
        --
        --- @diagnostic disable-next-line:redefined-local
        for _, nr in ipairs(vim.api.nvim_list_bufs()) do
            if bufnr ~= nr then
                local name = vim.api.nvim_buf_get_name(nr)
                if name == old_bufname then
                    vim.api.nvim_buf_delete(nr, { force = true })
                end
            end
        end
    end

    --
    -- Configure buffer options for directory & file
    --

    -- If a directory, we want to mark as such and prevent modifying;
    -- otherwise, in all other cases we treat this as a remote file
    if opts.is_dir then
        log.fmt_debug('Setting buffer %s as a directory', bufnr)

        -- Mark the buftype as nofile and not modifiable as you cannot
        -- modify it or write it; also explicitly set a custom filetype
        vim.bo[bufnr].filetype = 'distant-dir'
        vim.bo[bufnr].buftype = 'nofile'
        vim.bo[bufnr].modifiable = false

        -- If enabled, apply our directory keymappings
        local keymap = plugin.settings.keymap.dir
        if keymap.enabled then
            local nav = require('distant.nav')
            mapper.apply_mappings(bufnr, {
                [keymap.copy]     = nav.actions.copy,
                [keymap.edit]     = nav.actions.edit,
                [keymap.metadata] = nav.actions.metadata,
                [keymap.newdir]   = nav.actions.mkdir,
                [keymap.newfile]  = nav.actions.newfile,
                [keymap.rename]   = nav.actions.rename,
                [keymap.remove]   = nav.actions.remove,
                [keymap.up]       = nav.actions.up,
            })
        end
    else
        log.fmt_debug('Setting buffer %s as a file', bufnr)

        -- Mark the buftype as acwrite as you can still write to it, but we
        -- control where it is going
        vim.bo[bufnr].buftype = 'acwrite'

        -- If enabled, apply our file keymappings
        local keymap = plugin.settings.keymap.file
        if keymap.enabled then
            local nav = require('distant.nav')
            mapper.apply_mappings(bufnr, {
                [keymap.up] = nav.actions.up,
            })
        end
    end

    --
    -- Add stateful information to the buffer, helping keep track of it
    --

    log.fmt_debug('Storing variables for buffer %s', bufnr)
    local buffer = plugin.buf(bufnr)

    -- Ensure that we have a client configured
    buffer.set_client_id(
        opts.client_id or
        assert(
            plugin:active_client_id(),
            ('Buffer %s opened without a distant client'):format(bufnr)
        )
    )

    -- Set our path information
    buffer.set_path(opts.canonicalized_path)
    buffer.set_type(opts.is_dir and 'dir' or 'file')

    -- Add the raw path as an alternative path that can be used
    -- to look up this buffer
    buffer.add_alt_path(opts.raw_path, { dedup = true })

    -- Set our watched status to false only if not set yet
    if buffer.watched() == nil then
        buffer.set_watched(false)
    end

    -- Ensure that the data has been stored
    log.fmt_debug('Buffer %s stored variables: %s', bufnr, buffer.assert_data())

    -- Update the buffer name to proper reflect
    -- NOTE: This MUST be done after we set our variables, otherwise
    --       this will trigger entering a buffer and result
    --       in trying to load the buffer that is already loaded
    --       without being properly initialized
    log.fmt_debug('Setting buffer %s name to %s', bufnr, bufname)
    set_bufname(bufnr, bufname)

    -- Display the buffer in the specified window, defaulting to current
    vim.api.nvim_win_set_buf(winnr, bufnr)

    --
    -- Configure extra file details & LSP clients
    --

    if opts.is_file or opts.missing then
        -- Set our filetype to whatever the contents actually are (or file extension is)
        local success, filetype = pcall(vim.filetype.match, { buf = bufnr })
        if success and filetype then
            log.fmt_debug('Setting buffer %s filetype to %s', bufnr, filetype)
            vim.bo[bufnr].filetype = filetype
        end

        -- Launch any associated LSP clients
        local client = assert(
            plugin:client(opts.client_id),
            'No connection has been established!'
        )
        client:connect_lsp_clients({
            bufnr = bufnr,
            path = buffer.assert_path(),
            scheme = buffer.name.prefix(),
            settings = plugin:server_settings_for_client().lsp,
        })
    end

    --
    -- Configure file watching
    --

    -- If this file exists and is not being watched, we can notify distant to watch it
    if opts.is_file and not buffer.watched() then
        -- This should be set at this point from above configuration
        local client_id = assert(buffer.client_id())

        -- Update our status so we don't do this again
        buffer.set_watched(true)

        -- Attempt to watch the path
        plugin.api(client_id).watch({ path = buffer.assert_path() }, function(err, watcher)
            -- If failed to watch, reset our status and then error
            if err then
                buffer.set_watched(false)
                vim.notify(tostring(err), vim.log.levels.ERROR)
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
                --     b. If `reload` is DETECt, reset syntax highlighting/clear marks/diff status/etc; force fileformat and encoding
                -- 5. Undo file is unusable and overwritten
                local buf_modified = vim.bo[bufnr].modified

                --- @type 'conflict'|'changed'|'deleted'|''
                local reason =
                    ((change.kind == 'access' or change.kind == 'modify') and (buf_modified and 'conflict' or 'changed'))
                    or (change.kind == 'delete' and 'deleted')
                    or ''

                --- @type 'none'|'normal'|'detect'
                local reload = 'none'
                local can_reload = false
                if reason ~= '' then
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
                                can_reload = true
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
                                can_reload = true

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

                if can_reload then
                    local choice = vim.fn.input({ prompt = '&OK\n&Load File\nLoad File &and Options', default = '' })
                    if choice == 2 then
                        reload = 'normal'
                    elseif choice == 3 then
                        reload = 'detect'
                    else
                        reload = 'none'
                    end
                end

                if reload ~= 'none' then
                    -- TODO: Support detect mode
                    vim.api.nvim_exec_autocmds('BufReadCmd', {
                        group = 'distant',
                        pattern = bufname,
                    })
                end
            end)
        end)
    end
end

return M
