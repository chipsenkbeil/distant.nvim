local fn = require('distant.fn')
local g = require('distant.internal.globals')
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
        local prefix = 'buf_' .. buf .. 'key_' .. string.gsub(lhs, '.', string.byte) .. '_'
        local id = g.data.insert(rhs, prefix)
        table.insert(fn_ids, id)
        local key_mapping = '<Cmd>' .. g.data.get_as_key_mapping(id) .. '<CR>'
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
                    g.data.remove(id)
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
    local metadata = fn.metadata(path, u.merge(opts, {canonicalize = true}))

    local missing = metadata == nil
    local is_dir = not missing and metadata.file_type == 'dir'
    local is_file = not missing and metadata.file_type == 'file'
    local is_symlink = not missing and metadata.file_type == 'sym_link'

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
return function(path, opts)
    assert(type(path) == 'string', 'path must be a string')
    opts = opts or {}

    local p = check_path(path, opts)

    -- Figure out the buffer name, which is just its full path with
    -- a schema prepended
    local buf_name = 'distant://' .. p.path
    local buf = vim.fn.bufnr(buf_name)
    local buf_exists = buf ~= -1

    -- If we already have a buffer and we are not reloading, just
    -- switch to it
    if buf_exists and not opts.reload then
        vim.api.nvim_win_set_buf(0, buf)
        return
    end

    -- If the path points to a directory, load the entries as lines
    local lines = nil
    if p.is_dir then
        local entries = fn.dir_list(p.path, opts)
        lines = u.filter_map(entries, function(entry)
            if entry.depth > 0 then
                return entry.path
            end
        end)

    -- If path points to a file (or symlink), load its contents as lines
    elseif p.is_file or p.is_symlink then
        local text = fn.read_file_text(p.path, opts)
        lines = vim.split(text, '\n', true)

    -- Otherwise, we set ourselves up to create a new, empty file
    else
        lines = {}
    end

    -- Create a buffer to house the text if no buffer exists
    if not buf_exists then
        buf = vim.api.nvim_create_buf(true, false)
        assert(buf ~= 0, 'Failed to create buffer for remote editing')
    end

    -- Set the content of the buffer to the remote file
    vim.api.nvim_buf_set_option(buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(buf, 0, 1, false, lines)
    if p.is_dir then
        vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    end

    -- Since we modified the buffer by adding in the content for
    -- a file or directory, we need to reset it here
    vim.api.nvim_buf_set_option(buf, 'modified', false)

    -- If our buffer already existed, this is all we want to do as everything
    -- beyond this point is first-time setup
    if buf_exists then
        return
    end

    -- Set the buffer name to include a schema, which will trigger our
    -- autocmd for writing to the remote destination in the situation
    -- where we are editing a file
    vim.api.nvim_buf_set_name(buf, buf_name)

    -- If a directory, we want to mark as such and prevent modifying
    if p.is_dir then
        -- Mark the buftype as nofile and not modifiable as you cannot
        -- modify it or write it; also explicitly set a custom filetype
        vim.api.nvim_buf_set_option(buf, 'filetype', 'distant-dir')
        vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
        vim.api.nvim_buf_set_option(buf, 'modifiable', false)

        apply_mappings(buf, g.settings.nav.mappings)

    -- Otherwise, in all other cases we treat this as a remote file
    else
        -- Mark the buftype as acwrite as you can still write to it, but we
        -- control where it is going
        vim.api.nvim_buf_set_option(buf, 'buftype', 'acwrite')

        apply_mappings(buf, g.settings.file.mappings)
    end

    -- Add stateful information to the buffer, helping keep track of it
    v.buf.set_remote_path(buf, p.path)

    -- Display the buffer in the specified window, defaulting to current
    vim.api.nvim_win_set_buf(opts.win or 0, buf)

    if p.is_file then
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
    end
end
