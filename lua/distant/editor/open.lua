local fn    = require('distant.fn')
local state = require('distant.state')

local data  = require('distant-core').data
local log   = require('distant-core').log
local utils = require('distant-core').utils
local vars  = require('distant-core').vars

--- Applies neovim buffer-local mappings
---
--- @param bufnr number
--- @param mappings table<string, fun()>
local function apply_mappings(bufnr, mappings)
    log.fmt_trace('apply_mappings(%s, %s)', bufnr, mappings)

    -- Take the global mappings specified for navigation and apply them
    -- TODO: Since these mappings are global, should we set them once
    --       elsewhere and look them up by key instead?
    local fn_ids = {}
    for lhs, rhs in pairs(mappings) do
        local id = 'buf_' .. bufnr .. '_key_' .. string.gsub(lhs, '.', string.byte)
        data.set(id, rhs)
        table.insert(fn_ids, id)
        local key_mapping = '<Cmd>' .. data.get_as_key_mapping(id) .. '<CR>'
        vim.api.nvim_buf_set_keymap(bufnr, 'n', lhs, key_mapping, {
            noremap = true,
            silent = true,
            nowait = true,
        })
    end

    -- When the buffer is detached, we want to clear the global functions
    if not vim.tbl_isempty(fn_ids) then
        vim.api.nvim_buf_attach(bufnr, false, {
            on_detach = function()
                for _, id in ipairs(fn_ids) do
                    data.remove(id)
                end
            end,
        })
    end
end

--- @class distant.editor.open.CheckPathOpts
--- @field timeout? number #Maximum time to wait for a response (optional)
--- @field interval? number #Time in milliseconds to wait between checks for a response (optional)

--- @class distant.editor.open.CheckPathResult
--- @field path string #canonicalized path where possible, otherwise input path
--- @field is_dir boolean #true if path represents a directory
--- @field is_file boolean #true if path represents a normal file
--- @field missing boolean #true if path does not exist remotely

--- Checks a path to see if it exists, returning a table with information
---
--- @param path string Path to directory to show
--- @param opts? distant.editor.open.CheckPathOpts
--- @return distant.editor.open.CheckPathResult
local function check_path(path, opts)
    opts = opts or {}
    log.fmt_trace('check_path(%s, %s)', path, opts)

    -- We need to figure out if we are working with a file or directory
    local err, metadata = fn.metadata(vim.tbl_extend('keep', {
        path = path,
        canonicalize = true,
        resolve_file_type = true,
    }, opts))

    -- Check if the error we got is a missing file. If we get
    -- any other kind of error, we want to throw the error
    --
    -- TODO: With ssh, the error kind is "other" instead of "not_found"
    --       so we may have to do a batch request with exists
    --       to properly validate
    local missing = (err and err.kind == 'not_found') or false
    assert(not err or missing, tostring(err))

    local is_dir = false
    local is_file = false
    local full_path = path

    if not missing then
        assert(metadata, 'Metadata missing')

        is_dir = metadata.file_type == 'dir'
        is_file = metadata.file_type == 'file'

        -- Use canonicalized path if available
        full_path = metadata.canonicalized_path or path
    end

    return {
        path = full_path,
        is_dir = is_dir,
        is_file = is_file,
        missing = missing,
    }
end

--- Schedules a repair of quickfix markers.
---
--- In the situation where a buf already existed but was not initialized,
--- this is from a list like a quickfix list that had created a buf for
--- a non-file (distant://...) with markers in place before content.
---
--- NOTE: Calling nvim_buf_set_lines invokes `qf_mark_adjust` through `mark_adjust`,
---       which causes the lnum of quickfix, location-list, and marks to get moved
---       incorrectly when we are first populating (going from 1 line to N lines);
---       so, we want to spawn a task that will correct line numbers when shifted
---
--- @param bufnr number #buffer whose markers to repair
local function schedule_repair_markers(bufnr)
    local list = vim.fn.getqflist({ id = 0, context = 0 })
    local qfid = list.id

    if list.context and list.context.distant then
        vim.schedule(function()
            list = vim.fn.getqflist({ id = qfid, idx = 0, items = 0 })

            -- If we get lnum > end_lnum, this is from the marker from
            -- the quickfix list getting pushed down from new lines
            for _, item in ipairs(list.items) do
                if item.bufnr == bufnr and item.lnum > item.end_lnum then
                    item.lnum = item.end_lnum
                end
            end

            -- Update list and restore the selected position
            vim.fn.setqflist({}, 'r', { id = list.id, items = list.items })
            vim.fn.setqflist({}, 'a', { id = list.id, idx = list.idx })
        end)
    end
end

--- In the situation where we were loaded by a quickfix list, this moves
--- the cursor to the appropriate location based on the selection.
---
--- Position is only set if distant quickfix with matching buffer for selection
---
--- @param bufnr number
--- @return {line: number, col: number}|nil
local function get_qflist_selection_cursor(bufnr)
    local list = vim.fn.getqflist({ id = 0, context = 0 })
    local qfid = list.id

    if list.context and list.context.distant then
        list = vim.fn.getqflist({ id = qfid, idx = 0, items = 0 })

        -- Get line and column from entry only if it is for this buffer
        if list.idx > 0 then
            local item = list.items[list.idx]

            if item and item.bufnr == bufnr then
                local line = item.lnum or 1
                local col = item.col or 0
                local end_line = item.end_lnum or line
                local end_col = item.end_col or col

                if line > end_line then
                    line = end_line
                end

                if col > end_col then
                    col = end_col
                end

                return { line = line, col = col }
            end
        end
    end
end

--- @param bufnr number
--- @param lines string[]
local function create_or_populate_buf(bufnr, lines)
    log.fmt_trace('create_or_populate_buf(%s, %s)', bufnr, lines)
    local buf_exists = bufnr ~= -1

    -- Create a buffer to house the text if no buffer exists
    if not buf_exists then
        bufnr = vim.api.nvim_create_buf(true, false)
        assert(bufnr ~= 0, 'Failed to create buffer for remote editing')
    end

    -- Place lines into buffer, marking the file as modifiable
    -- temporarily so we can load lines, and then changing it back
    -- to whatever state it was before
    --
    -- Since we modified the buffer by adding in the content,
    -- we need to reset it here
    local is_modifiable = vim.api.nvim_buf_get_option(bufnr, 'modifiable')
    vim.api.nvim_buf_set_option(bufnr, 'modifiable', true)
    local line_cnt = vim.api.nvim_buf_line_count(bufnr)
    if line_cnt == 0 then
        line_cnt = 1
    end

    -- In the situation where a buf already existed but was not initialized,
    -- this is from a list like a quickfix list that had created a buf for
    -- a non-file (distant://...) with markers in place before content
    --
    -- NOTE: Calling nvim_buf_set_lines invokes `qf_mark_adjust` through `mark_adjust`,
    --       which causes the lnum of quickfix, location-list, and marks to get moved
    --       incorrectly when we are first populating (going from 1 line to N lines);
    --       so, we want to spawn a task that will correct line numbers when shifted
    if buf_exists and vars.buf(bufnr).remote_path:is_unset() then
        schedule_repair_markers(bufnr)
    end

    vim.api.nvim_buf_set_lines(bufnr, 0, line_cnt, false, lines)

    vim.api.nvim_buf_set_option(bufnr, 'modifiable', is_modifiable)
    vim.api.nvim_buf_set_option(bufnr, 'modified', false)

    return bufnr
end

--- @param path string
--- @param bufnr number
--- @param opts? distant.api.ReadFileTextOpts
local function load_buf_from_file(path, bufnr, opts)
    opts = opts or {}
    log.fmt_trace('load_buf_from_file(%s, %s, %s)', path, bufnr, opts)
    local err, text = fn.read_file_text(vim.tbl_extend('keep', { path = path }, opts))
    assert(not err, tostring(err))

    local lines
    if text ~= nil then
        lines = vim.split(text, '\n', { plain = true })
    else
        log.fmt_error('Failed to read file: %s', path)
        return bufnr
    end

    return create_or_populate_buf(bufnr, lines)
end

--- @param path string
--- @param bufnr number
--- @param opts? distant.api.ReadDirOpts
local function load_buf_from_dir(path, bufnr, opts)
    opts = opts or {}
    log.fmt_trace('load_buf_from_dir(%s, %s, %s)', path, bufnr, opts)

    local err, res = fn.read_dir(vim.tbl_extend('keep', { path = path }, opts))
    assert(not err, tostring(err))
    assert(res, 'Impossible: read_dir result nil')

    local lines = assert(utils.filter_map(res.entries, function(entry)
        if entry.depth > 0 then
            return entry.path
        end
    end), 'Impossible: Lines is nil')

    return create_or_populate_buf(bufnr, lines)
end

--- @param p distant.editor.open.CheckPathResult
--- @param bufnr number
--- @param opts? distant.api.ReadDirOpts|distant.api.ReadFileTextOpts
local function load_content(p, bufnr, opts)
    opts = opts or {}
    log.fmt_trace('load_content(%s, %s, %s)', p, bufnr, opts)
    vim.validate({
        p = { p, 'table' },
        bufnr = { bufnr, 'number' },
        opts = { opts, 'table', true },
    })

    -- If the path points to a directory, load the entries as lines
    if p.is_dir then
        return load_buf_from_dir(p.path, bufnr, opts)

        -- If path points to a file, load its contents as lines
    elseif p.is_file then
        return load_buf_from_file(p.path, bufnr, opts)

        -- Otherwise, we set ourselves up to create a new, empty file
    else
        return create_or_populate_buf(bufnr, {})
    end
end

--- @class distant.editor.open.ConfigureBufOpts
--- @field bufnr number #number associated with the buffer
--- @field name string #name of the buffer (e.g. distant://path/to/file.txt)
--- @field canonicalized_path string #primary path (e.g. path/to/file.txt)
--- @field raw_path string #raw input path, which could be an alt path
--- @field is_dir boolean #true if buffer represents a directory
--- @field is_file boolean #true if buffer represents a file
--- @field winnr? number #window number to use

--- @param opts distant.editor.open.ConfigureBufOpts
local function configure_buf(opts)
    log.fmt_trace('configure_buf(%s)', opts)
    vim.validate({
        bufnr = { opts.bufnr, 'number' },
        name = { opts.name, 'string' },
        canonicalized_path = { opts.canonicalized_path, 'string' },
        raw_path = { opts.raw_path, 'string' },
        is_dir = { opts.is_dir, 'boolean' },
        is_file = { opts.is_file, 'boolean' },
        winnr = { opts.winnr, 'number', true },
    })

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

    set_bufname(bufnr, bufname)

    -- If a directory, we want to mark as such and prevent modifying
    if opts.is_dir then
        -- Mark the buftype as nofile and not modifiable as you cannot
        -- modify it or write it; also explicitly set a custom filetype
        vim.api.nvim_buf_set_option(bufnr, 'filetype', 'distant-dir')
        vim.api.nvim_buf_set_option(bufnr, 'buftype', 'nofile')
        vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)

        apply_mappings(bufnr, state.settings.dir.mappings)

        -- Otherwise, in all other cases we treat this as a remote file
    else
        -- Mark the buftype as acwrite as you can still write to it, but we
        -- control where it is going
        vim.api.nvim_buf_set_option(bufnr, 'buftype', 'acwrite')

        apply_mappings(bufnr, state.settings.file.mappings)
    end

    -- Add stateful information to the buffer, helping keep track of it
    (function()
        local v = vars.buf(bufnr)
        v.remote_path:set(opts.canonicalized_path)
        v.remote_type:set(opts.is_dir and 'dir' or 'file')

        -- Add the raw path as an alternative path that can be used
        -- to look up this buffer
        local alt_paths = v.remote_alt_paths:get() or {}
        table.insert(alt_paths, opts.raw_path)
        v.remote_alt_paths:set(alt_paths)
    end)()

    -- Display the buffer in the specified window, defaulting to current
    vim.api.nvim_win_set_buf(winnr, bufnr)

    if opts.is_file then
        -- Set our filetype to whatever the contents actually are (or file extension is)
        -- TODO: This makes me feel uncomfortable as I do not yet understand why detecting
        --       the filetype as the real type does not trigger neovim's LSP. At the
        --       moment, it does not happen but we still get syntax highlighting, which
        --       is perfect. In the future, we may need to switch this to something similar
        --       to what telescope.nvim does with plenary.nvim's syntax functions.
        --
        -- TODO: Does this work if the above window is not the current one? Would prefer
        --       an explicit function as opposed to the command we're using as don't
        --       have control
        vim.cmd([[ filetype detect ]])

        -- Launch any associated LSP clients
        assert(state.client, 'No connection has been established!')
        state.client:connect_lsp_clients({ bufnr = bufnr, settings = state.settings.lsp })
    end
end

--- @class distant.editor.OpenOpts
--- @field path string #Path to file or directory
--- @field bufnr? number #If not -1 and number, will use this buffer number instead of looking for a buffer
--- @field winnr? number #If not -1 and number, will use this window
--- @field line? number #If provided, will jump to the specified line (1-based index)
--- @field col? number #If provided, will jump to the specified column (1-based index)
--- @field reload? boolean #If true, will reload the buffer even if already open
--- @field timeout? number #Maximum time to wait for a response
--- @field interval? number #Time in milliseconds to wait between checks for a response

--- Opens the provided path in one of three ways:
---
--- 1. If path points to a file, creates a new `distant` buffer with the contents
--- 2. If path points to a directory, opens up a navigation interface
--- 3. If path does not exist, opens a blank buffer that points to the file to be written
---
--- @param opts distant.editor.OpenOpts|string
--- @return number|nil #The handle of the created buffer for the remote file/directory, or nil if failed
return function(opts)
    opts = opts or {}
    log.fmt_trace('editor.open(%s)', opts)

    local path
    if type(opts) == 'string' then
        path = opts
        opts = { path = path }
    elseif type(opts) == 'table' then
        path = opts.path
    end

    vim.validate({ opts = { opts, 'table' } })

    -- Ensure that local_path is without prefix and path is with prefix
    local local_path = utils.strip_prefix(path, 'distant://')
    path = 'distant://' .. path

    -- Determine if we already have a buffer with the matching name
    local bufnr = vars.find_buf_with_path(local_path) or -1
    local buf_exists = bufnr ~= -1

    -- Retrieve information about our path, capturing the canonicalized path
    -- if possible without the distant:// prefix
    local p = check_path(local_path, { timeout = opts.timeout, interval = opts.interval })
    log.fmt_debug('retrieved path info for %s: %s', p.path, p)

    -- Construct universal remote buffer name (distant:// + canonicalized path)
    local buf_name = 'distant://' .. p.path
    log.fmt_debug('does buf %s exist? %s', buf_name, buf_exists and 'yes' or 'no')

    -- If we were given a different buf than what matched, then we have a duplicate
    -- which can happen from symlinks and we want to merge by unloading the duplicate
    -- buffer and using the matched buffer
    --
    -- NOTE: The assumption is that only one of these buffers will be initialized
    --       and shown; so, completely deleting the other buffer should not be a
    --       problem. The main change required is updating the quickfix lists that
    --       refer to the wrong buffer
    if buf_exists and type(opts.bufnr) == 'number' and opts.bufnr > 0 and opts.bufnr ~= bufnr then
        -- TODO: Update all quickfix lists with new buffer number, which involves
        --       a vim.schedule since we cannot update quickfix lists here if
        --       invoked from an autocommand
        vim.api.nvim_buf_delete(opts.bufnr, { force = true })
    end

    -- If the buffer didn't exist already (or if forcing reload), load contents
    -- into the buffer, optionally creating it if the buffer id is -1
    local cursor = { line = opts.line, col = opts.col }
    if not buf_exists or opts.reload then
        local view
        if buf_exists then
            view = vim.fn.winsaveview()
            log.fmt_trace('buf %s, winsaveview() = %s', bufnr, view)

            -- Special case where a quickfix list created the buffer without content
            if vars.buf(bufnr).remote_path:is_unset() then
                local override = get_qflist_selection_cursor(bufnr)
                if override then
                    cursor = override
                    log.fmt_trace('buf %s, override cursor = %s', bufnr, cursor)
                end
            end
        end

        -- Load content and either place it inside the provided buffer or create
        -- a new buffer in one is not provided (buf <= 0)
        bufnr = load_content(p, bufnr, opts)
        log.fmt_debug('loaded %s into buf %s', p.path, bufnr)

        if buf_exists then
            vim.fn.winrestview(view)
            log.fmt_trace('buf %s, winrestview()', bufnr)
        end
    end

    -- Reconfigure the buffer, setting its name and various properties as well as
    -- launching and attaching LSP clients if necessary
    configure_buf({
        bufnr = bufnr,
        name = buf_name,
        canonicalized_path = p.path,
        raw_path = local_path,
        is_dir = p.is_dir,
        is_file = p.is_file or p.missing,
        winnr = opts.winnr,
    })

    -- Update position in buffer if provided new position
    if cursor.line ~= nil or cursor.col ~= nil then
        --- @type number, number
        local cur_line, cur_col = unpack(vim.api.nvim_win_get_cursor(opts.winnr or 0))
        local line = cursor.line or cur_line
        local col = cursor.col
        -- Input col is base index 1, whereas vim takes index 0
        if col then
            col = col - 1
        end
        col = col or cur_col
        vim.schedule(function()
            vim.api.nvim_win_set_cursor(opts.winnr or 0, { line, col })
        end)
    end

    -- Final check to make sure we aren't returning a garbage buffer number
    assert(bufnr > 0, 'Invalid bufnr being returned')
    return bufnr
end
