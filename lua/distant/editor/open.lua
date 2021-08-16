local fn = require('distant.fn')
local s = require('distant.internal.state')
local u = require('distant.internal.utils')
local v = require('distant.internal.vars')

--- Applies neovim buffer-local mappings
---
--- @param buf number
--- @param mappings table
local function apply_mappings(buf, mappings)
    -- Take the global mappings specified for navigation and apply them
    -- TODO: Since these mappings are global, should we set them once
    --       elsewhere and look them up by key instead?
    local fn_ids = {}
    for lhs, rhs in pairs(mappings) do
        local id = 'buf_' .. buf .. '_key_' .. string.gsub(lhs, '.', string.byte)
        s.data.set(id, rhs)
        table.insert(fn_ids, id)
        local key_mapping = '<Cmd>' .. s.data.get_as_key_mapping(id) .. '<CR>'
        vim.api.nvim_buf_set_keymap(buf, 'n', lhs, key_mapping, {
            noremap = true,
            silent = true,
            nowait = true,
        })
    end

    -- When the buffer is detached, we want to clear the global functions
    if not vim.tbl_isempty(fn_ids) then
        vim.api.nvim_buf_attach(buf, false, {
            on_detach = function()
                for _, id in ipairs(fn_ids) do
                    s.data.remove(id)
                end
            end;
        })
    end
end

--- Checks a path to see if it exists, returning a table with information
---
--- @param path string Path to directory to show
--- @param opts.timeout number Maximum time to wait for a response (optional)
--- @param opts.interval number Time in milliseconds to wait between checks for a response (optional)
--- @return table #Table containing `path`, `is_dir`, `is_file`, `is_symlink`, and `missing` fields
local function check_path(path, opts)
    -- We need to figure out if we are working with a file or directory
    local _, metadata = fn.metadata(path, u.merge(opts, {canonicalize = true}))

    local missing = metadata == nil
    local is_dir = not missing and metadata.file_type == 'dir'
    local is_file = not missing and metadata.file_type == 'file'
    local is_symlink = not missing and metadata.file_type == 'symlink'

    -- Use canonicalized path if available
    local full_path = path
    if not missing then
        full_path = metadata.canonicalized_path or path
    end

    return {
        path = full_path,
        is_dir = is_dir,
        is_file = is_file,
        is_symlink = is_symlink,
        missing = missing,
    }
end

local function create_or_populate_buf(buf, lines)
    -- Create a buffer to house the text if no buffer exists
    if buf == -1 then
        buf = vim.api.nvim_create_buf(true, false)
        assert(buf ~= 0, 'Failed to create buffer for remote editing')
    end

    -- Place lines into buffer, marking the file as modifiable
    -- temporarily so we can load lines, and then changing it back
    -- to whatever state it was before
    --
    -- Since we modified the buffer by adding in the content,
    -- we need to reset it here
    local is_modifiable = vim.api.nvim_buf_get_option(buf, 'modifiable')
    vim.api.nvim_buf_set_option(buf, 'modifiable', true)
    local line_cnt = vim.api.nvim_buf_line_count(buf)
    if line_cnt == 0 then
        line_cnt = 1
    end
    vim.api.nvim_buf_set_lines(buf, 0, line_cnt, false, lines)
    vim.api.nvim_buf_set_option(buf, 'modifiable', is_modifiable)
    vim.api.nvim_buf_set_option(buf, 'modified', false)

    return buf
end

local function load_buf_from_file(path, buf, opts)
    local err, text = fn.read_file_text(path, opts)
    assert(not err, err)

    local lines
    if text ~= nil then
        lines = vim.split(text, '\n', true)
    else
        u.log_err('Failed to read file: ' .. path)
        return buf
    end

    return create_or_populate_buf(buf, lines)
end

local function attach_buf_autocmds(buf)
    local pattern = '<buffer=' .. buf .. '>'

    -- BEGIN GROUP
    vim.cmd([[ augroup distant ]])

    -- {write id, read id, unload id}
    local ids = {
        'buf_' .. buf .. '_write_' .. u.next_id(),
        'buf_' .. buf .. '_read_' .. u.next_id(),
        'buf_' .. buf .. '_delete_' .. u.next_id(),
    }

    -- Register a command on the buffer to forward writes
    s.data.set(ids[1], function() require('distant.editor.write')(buf) end)
    local write_cmd = s.data.get_as_key_mapping(ids[1])
    vim.cmd('autocmd BufWriteCmd ' .. pattern .. ' ' .. write_cmd)

    -- Register a command on the buffer to forward reloads
    s.data.set(ids[2], function()
        local path = v.buf.remote_path(buf)
        if path ~= nil then
            load_buf_from_file(path, buf)

            -- Once content is added, we've lost our filetype syntax highlighting
            -- (the type is still there) along with attached LSP clients
            apply_mappings(buf, s.settings.file.mappings)
            vim.cmd([[ syntax on ]])
            s.lsp.connect(buf)
        end
    end)
    local read_cmd = s.data.get_as_key_mapping(ids[2])
    vim.cmd('autocmd BufReadCmd ' .. pattern .. ' ' .. read_cmd)

    -- Register a command to remove callbacks when buffer deleted
    s.data.set(ids[3], function()
        for _, id in ipairs(ids) do
            s.data.remove(id)
        end
    end)
    local delete_cmd = s.data.get_as_key_mapping(ids[3])
    vim.cmd('autocmd BufDelete ' .. pattern .. ' ' .. delete_cmd)

    -- END GROUP
    vim.cmd([[ augroup END ]])
end

local function load_buf_from_dir(path, buf, opts)
    local err, entries = fn.dir_list(path, opts)
    assert(not err, err)

    local lines = u.filter_map(entries, function(entry)
        if entry.depth > 0 then
            return entry.path
        end
    end)

    -- Create a buffer to house the text if no buffer exists
    if buf == -1 then
        buf = vim.api.nvim_create_buf(true, false)
        assert(buf ~= 0, 'Failed to create buffer for remote editing')
    end

    return create_or_populate_buf(buf, lines)
end

local function load_content(p, buf, opts)
    -- If the path points to a directory, load the entries as lines
    if p.is_dir then
        return load_buf_from_dir(p.path, buf, opts)

    -- If path points to a file (or symlink), load its contents as lines
    elseif p.is_file or p.is_symlink then
        return load_buf_from_file(p.path, buf, opts)

    -- Otherwise, we set ourselves up to create a new, empty file
    else
        return create_or_populate_buf(buf, {})
    end
end

local function configure_buf(args)
    assert(type(args.buf) == 'number')
    assert(type(args.name) == 'string')
    assert(type(args.path) == 'string')
    assert(type(args.is_dir) == 'boolean')
    assert(type(args.is_file) == 'boolean')
    assert(args.win == nil or type(args.win) == 'number')

    -- Set the buffer name to include a schema, which will trigger our
    -- autocmd for writing to the remote destination in the situation
    -- where we are editing a file
    vim.api.nvim_buf_set_name(args.buf, args.name)

    -- If a directory, we want to mark as such and prevent modifying
    if args.is_dir then
        -- Mark the buftype as nofile and not modifiable as you cannot
        -- modify it or write it; also explicitly set a custom filetype
        vim.api.nvim_buf_set_option(args.buf, 'filetype', 'distant-dir')
        vim.api.nvim_buf_set_option(args.buf, 'buftype', 'nofile')
        vim.api.nvim_buf_set_option(args.buf, 'modifiable', false)

        apply_mappings(args.buf, s.settings.dir.mappings)

    -- Otherwise, in all other cases we treat this as a remote file
    else
        -- Mark the buftype as acwrite as you can still write to it, but we
        -- control where it is going
        vim.api.nvim_buf_set_option(args.buf, 'buftype', 'acwrite')

        apply_mappings(args.buf, s.settings.file.mappings)
    end

    -- Add stateful information to the buffer, helping keep track of it
    v.buf.set_remote_path(args.buf, args.path)
    v.buf.set_remote_type(
        args.buf,
        args.is_dir and 'dir' or
        args.is_file and 'file' or
        'symlink'
    )

    -- Display the buffer in the specified window, defaulting to current
    vim.api.nvim_win_set_buf(args.win or 0, args.buf)

    if args.is_file then
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

        -- Ensure that reading/writing gets translated remotely
        attach_buf_autocmds(args.buf)

        -- Launch any associated LSP clients
        s.lsp.connect(args.buf)
    end
end

--- Opens the provided path in one of three ways:
---
--- 1. If path points to a file, creates a new `distant` buffer with the contents
--- 2. If path points to a directory, opens up a navigation interface
--- 3. If path does not exist, opens a blank buffer that points to the file to be written
---
--- @param path string Path to directory to show
--- @param opts.reload boolean If true, will reload the buffer even if already open
--- @param opts.timeout number Maximum time to wait for a response (optional)
--- @param opts.interval number Time in milliseconds to wait between checks for a response (optional)
--- @return number|nil #The handle of the created buffer for the remote file/directory, or nil if failed
return function(path, opts)
    assert(type(path) == 'string', 'path must be a string')
    opts = opts or {}

    -- Retrieve information about our path
    local p = check_path(path, opts)

    -- Determine if we already have a buffer with the matching name
    local buf_name = p.path
    local buf = vim.fn.bufnr('^' .. buf_name .. '$')
    local buf_exists = buf ~= -1

    -- If we already have a buffer and we are not reloading, just
    -- switch to it
    if buf_exists and not opts.reload then
        vim.api.nvim_win_set_buf(0, buf)
        return buf
    end

    -- Load content and either place it inside the provided buffer or create
    -- a new buffer in one is not provided (buf == -1)
    buf = load_content(p, buf, opts)

    -- If our buffer already existed, this is all we want to do as everything
    -- beyond this point is first-time setup
    if buf_exists then
        return buf
    end

    configure_buf({
        buf = buf;
        name = buf_name;
        path = p.path;
        is_dir = p.is_dir;
        is_file = p.is_file or p.missing;
        win = opts.win;
    })

    return buf
end
