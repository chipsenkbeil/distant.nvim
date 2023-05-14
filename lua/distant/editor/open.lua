local plugin       = require('distant')

local log          = require('distant-core').log
local utils        = require('distant-core').utils

local checker      = require('distant.editor.open.checker')
local configurator = require('distant.editor.open.configurator')
local loader       = require('distant.editor.open.loader')
local qflist       = require('distant.editor.open.qflist')

--- @class distant.editor.OpenOpts
--- @field path string #Path to file or directory
--- @field bufnr? number #If not -1 and number, will use this buffer number instead of looking for a buffer
--- @field winnr? number #If not -1 and number, will use this window
--- @field line? number #If provided, will jump to the specified line (1-based index)
--- @field col? number #If provided, will jump to the specified column (1-based index)
--- @field reload? boolean #If true, will reload the buffer even if already open
--- @field client_id? string #Id of the client to use to load the buffer
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

    --- @type string|nil
    local client_id = opts.client_id
    if client_id ~= nil then
        log.fmt_debug('Using explicit client %s', client_id)
    end

    --------------------------------------------------------------------------
    -- CLEAN UP OPTIONS
    --------------------------------------------------------------------------

    if type(opts) == 'string' then
        opts = { path = opts }
    end

    --------------------------------------------------------------------------
    -- SPLIT REMOTE AND LOCAL PATHS
    --------------------------------------------------------------------------

    -- Ensure that local_path is without prefix and path is with prefix
    local local_path = utils.strip_prefix(opts.path, 'distant://')
    log.fmt_debug('Local path: %s', local_path)

    local path = 'distant://' .. local_path
    log.fmt_debug('Distant path: %s', path)

    --------------------------------------------------------------------------
    -- SEARCH FOR EXISTING PATH & USE ITS CLIENT
    --------------------------------------------------------------------------

    -- Determine if we already have a buffer with the matching name
    log.fmt_debug('Searching for buffer: %s', local_path)
    local buffer = plugin.buf.find({ path = local_path })
    local bufnr = buffer and buffer:bufnr()

    if bufnr ~= nil then
        log.fmt_debug('Found existing buffer: %s', bufnr)

        local new_client_id = plugin.buf(bufnr).client_id()
        if new_client_id ~= nil then
            -- This is an error where we are loading a buffer for
            -- a different client than specified, so fail!
            if client_id ~= nil and client_id ~= new_client_id then
                error(('Found buffer %s of client %s, but told to use client %s'):format(
                    bufnr, new_client_id, client_id
                ))
            end

            -- Update our client to point to the buffer's client
            client_id = new_client_id
            log.fmt_debug('Using existing buffer client: %s', client_id)
        end
    else
        log.debug('No buffer found.')
    end

    --------------------------------------------------------------------------
    -- EVALUATE PATH ON REMOTE MACHINE
    --------------------------------------------------------------------------

    -- Retrieve information about our path, capturing the canonicalized path
    -- if possible without the distant:// prefix
    log.fmt_debug('Evaluating path: %s', local_path)
    local path_info = checker.check_path({
        client_id = client_id,
        path = local_path,
        timeout = opts.timeout,
        interval = opts.interval,
    })

    -- Recheck if we have this buffer if no buffer was found earlier
    -- and the supplied path and evaluated path are different
    if buffer == nil and local_path ~= path_info.path then
        log.fmt_debug('Searching for buffer using evaluated path: %s', path_info.path)
        buffer = plugin.buf.find({ path = path_info.path })
        bufnr = buffer and buffer:bufnr()
        if bufnr ~= nil then
            log.fmt_debug('Found existing buffer: %s', bufnr)
        else
            log.debug('No buffer found.')
        end
    end

    -- Construct universal remote buffer name (distant:// + canonicalized path)
    local buf_name = 'distant://' .. path_info.path

    --------------------------------------------------------------------------
    -- CLEAR OUT EXISTING BUFFER
    --------------------------------------------------------------------------

    -- If we were given a different buf than what matched, then we have a duplicate
    -- which can happen from symlinks and we want to merge by unloading the duplicate
    -- buffer and using the matched buffer
    --
    -- NOTE: The assumption is that only one of these buffers will be initialized
    --       and shown; so, completely deleting the other buffer should not be a
    --       problem. The main change required is updating the quickfix lists that
    --       refer to the wrong buffer
    if bufnr ~= nil and opts.bufnr ~= nil and bufnr ~= opts.bufnr then
        -- TODO: Update all quickfix lists with new buffer number, which involves
        --       a vim.schedule since we cannot update quickfix lists here if
        --       invoked from an autocommand
        vim.api.nvim_buf_delete(opts.bufnr, { force = true })
    end

    --------------------------------------------------------------------------
    -- LOAD BUFFER CONTENTS
    --------------------------------------------------------------------------

    -- If the buffer didn't exist already (or if forcing reload), load contents
    -- into the buffer, creating it if there is no buffer
    local cursor = { line = opts.line, col = opts.col }
    if not bufnr or opts.reload then
        local view

        -- If the buffer already existed, we save the view of it
        if bufnr ~= nil then
            view = vim.fn.winsaveview()
            log.fmt_trace('Buffer %s :: winsaveview() = %s', bufnr, view)

            -- Special case where a quickfix list created the buffer without content
            if not plugin.buf(bufnr).has_data() then
                local override = qflist.get_qflist_selection_cursor(bufnr)
                if override then
                    cursor = override
                    log.fmt_trace('Buffer %s :: override cursor = %s', bufnr, cursor)
                end
            end
        end

        -- Load content and either place it inside the provided buffer or create
        -- a new buffer in one is not provided (buf <= 0)
        local results = loader.load({
            bufnr = bufnr,
            path = path_info.path,
            is_dir = path_info.is_dir,
            is_file = path_info.is_file,
            missing = path_info.missing,
            client_id = client_id,
            timeout = opts.timeout,
            interval = opts.interval,
        })

        -- If we had a buffer going into loading and came out with a different
        -- one, something went wrong and we need to fail
        if bufnr ~= nil and results.bufnr ~= bufnr then
            error(('Loaded contents into wrong buffer! Expected buffer %s, actual buffer %s'):format(
                bufnr, results.bufnr
            ))
        end

        -- Update buffer to be the one we loaded into
        bufnr = results.bufnr

        -- Report loading in debug
        if results.created then
            log.fmt_debug('Created buffer %s', results.bufnr)
        end
        log.fmt_debug('Loaded contents into buffer %s', bufnr)

        -- If we did not create the buffer, restore our view
        if not results.created then
            vim.fn.winrestview(view)
            log.fmt_trace('Buffer %s :: winrestview()', bufnr)
        end
    end

    --------------------------------------------------------------------------
    -- CONFIGURE BUFFER
    --------------------------------------------------------------------------

    -- Reconfigure the buffer, setting its name and various properties as well as
    -- launching and attaching LSP clients if necessary
    log.fmt_debug('Configuring buffer %s', bufnr)
    configurator.configure({
        bufnr = bufnr,
        name = buf_name,
        canonicalized_path = path_info.path,
        raw_path = local_path,
        is_dir = path_info.is_dir,
        is_file = path_info.is_file,
        missing = path_info.missing,
        client_id = client_id,
        winnr = opts.winnr,
    })

    --------------------------------------------------------------------------
    -- JUMP TO POSITION IN BUFFER
    --------------------------------------------------------------------------

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
            log.fmt_debug('Jumping to line %s, col %s in buffer %s', line, col)
            vim.api.nvim_win_set_cursor(opts.winnr or 0, { line, col })
        end)
    end

    --------------------------------------------------------------------------
    -- RETURN CREATED BUFFER
    --------------------------------------------------------------------------

    -- Final check to make sure we aren't returning a garbage buffer number
    assert(bufnr > 0, 'Invalid bufnr being returned')
    return bufnr
end
