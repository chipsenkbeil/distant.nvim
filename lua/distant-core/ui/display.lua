local log = require('distant-core.log')
local state = require('distant-core.ui.state')
local utils = require('distant-core.utils')

--- @alias distant.core.ui.display.WinWidth number
--- Width of the window. Accepts:
--- - Integer greater than 1 for fixed width.
--- - Float in the range of 0-1 for a percentage of screen width.

--- @alias distant.core.ui.display.WinHeight number
--- Height of the window. Accepts:
--- - Integer greater than 1 for fixed height.
--- - Float in the range of 0-1 for a percentage of screen height.

--- @type distant.core.ui.display.WinWidth
local DEFAULT_UI_WIDTH = 0.8

--- @type distant.core.ui.display.WinHeight
local DEFAULT_UI_HEIGHT = 0.9

--- @class distant.core.ui.Display
local M = {}

--- @generic T
--- @param debounced_fn fun(arg1: T)
--- @return fun(arg1: T)
local function debounced(debounced_fn)
    local queued = false
    local last_arg = nil
    return function(a)
        last_arg = a
        if queued then
            return
        end
        queued = true
        vim.schedule(function()
            debounced_fn(last_arg)
            queued = false
            last_arg = nil
        end)
    end
end

--- @param line string
--- @param render_context distant.core.ui.display.RenderContext
local function get_styles(line, render_context)
    local indentation = 0

    for i = 1, #render_context.applied_block_styles do
        local styles = render_context.applied_block_styles[i]
        for j = 1, #styles do
            local style = styles[j]
            if style == 'INDENT' then
                indentation = indentation + 2
            elseif style == 'CENTERED' then
                local padding = math.floor((render_context.viewport_context.win_width - #line) / 2)
                indentation = math.max(0, padding) -- CENTERED overrides any already applied indentation
            end
        end
    end

    return {
        indentation = indentation,
    }
end

--- @param viewport_context distant.core.ui.display.ViewportContext
--- @param node distant.core.ui.INode
--- @param _render_context? distant.core.ui.display.RenderContext
--- @param _output? distant.core.ui.display.RenderOutput
--- @return distant.core.ui.display.RenderOutput
local function render_node(viewport_context, node, _render_context, _output)
    --- @class distant.core.ui.display.RenderContext
    --- @field viewport_context distant.core.ui.display.ViewportContext
    --- @field applied_block_styles distant.core.ui.CascadingStyle[][]
    local render_context = _render_context
        or {
            viewport_context = viewport_context,
            applied_block_styles = {},
        }
    --- @class distant.core.ui.display.RenderHighlight
    --- @field hl_group string
    --- @field line number
    --- @field col_start number
    --- @field col_end number

    --- @class distant.core.ui.display.RenderKeybind
    --- @field line number
    --- @field key string
    --- @field effect string
    --- @field payload any

    --- @class distant.core.ui.display.RenderDiagnostic
    --- @field line number
    --- @field message string
    --- @field severity integer
    --- @field source? string

    --- @class distant.core.ui.display.RenderOutput
    --- @field lines string[]: The buffer lines.
    --- @field virt_texts {line: integer, content: distant.core.ui.Span}[]: List of tuples.
    --- @field highlights distant.core.ui.display.RenderHighlight[]
    --- @field keybinds distant.core.ui.display.RenderKeybind[]
    --- @field diagnostics distant.core.ui.display.RenderDiagnostic[]
    --- @field sticky_cursors { line_map: table<number, string>, id_map: table<string, number> }
    local output = _output
        or {
            lines = {},
            virt_texts = {},
            highlights = {},
            keybinds = {},
            diagnostics = {},
            sticky_cursors = { line_map = {}, id_map = {} },
        }

    if node.type == 'VIRTUAL_TEXT' then
        output.virt_texts[#output.virt_texts + 1] = {
            line = #output.lines - 1,
            content = node.virt_text,
        }
    elseif node.type == 'HL_TEXT' then
        for i = 1, #node.lines do
            local line = node.lines[i]
            local line_highlights = {}
            local full_line = ''
            for j = 1, #line do
                local span = line[j]
                local content, hl_group = span[1], span[2]
                local col_start = #full_line
                full_line = full_line .. content
                if hl_group ~= '' then
                    line_highlights[#line_highlights + 1] = {
                        hl_group = hl_group,
                        line = #output.lines,
                        col_start = col_start,
                        col_end = col_start + #content,
                    }
                end
            end

            local active_styles = get_styles(full_line, render_context)

            -- apply indentation
            full_line = (' '):rep(active_styles.indentation) .. full_line
            for j = 1, #line_highlights do
                local highlight = line_highlights[j]
                highlight.col_start = highlight.col_start + active_styles.indentation
                highlight.col_end = highlight.col_end + active_styles.indentation
                output.highlights[#output.highlights + 1] = highlight
            end

            output.lines[#output.lines + 1] = full_line
        end
    elseif node.type == 'NODE' or node.type == 'CASCADING_STYLE' then
        if node.type == 'CASCADING_STYLE' then
            render_context.applied_block_styles[#render_context.applied_block_styles + 1] = node.styles
        end
        for i = 1, #node.children do
            render_node(viewport_context, node.children[i], render_context, output)
        end
        if node.type == 'CASCADING_STYLE' then
            render_context.applied_block_styles[#render_context.applied_block_styles] = nil
        end
    elseif node.type == 'KEYBIND_HANDLER' then
        output.keybinds[#output.keybinds + 1] = {
            line = node.is_global and -1 or #output.lines,
            key = node.key,
            effect = node.effect,
            payload = node.payload,
        }
    elseif node.type == 'DIAGNOSTICS' then
        output.diagnostics[#output.diagnostics + 1] = {
            line = #output.lines,
            message = node.diagnostic.message,
            severity = node.diagnostic.severity,
            source = node.diagnostic.source,
        }
    elseif node.type == 'STICKY_CURSOR' then
        output.sticky_cursors.id_map[node.id] = #output.lines
        output.sticky_cursors.line_map[#output.lines] = node.id
    end

    return output
end

-- exported for tests
M._render_node = render_node

--- @alias distant.core.ui.display.Border
--- | '"none"'      # no border (default)
--- | '"single"'    # a single line box
--- | '"double"'    # a double line box
--- | '"rounded"'   # like "single", but with rounded corners
--- | '"solid"'     # adds padding by a single whitespace cell
--- | '"shadow"'    # a drop shadow effect by blending with the background

--- @class distant.core.ui.display.WindowOpts
--- @field effects? distant.core.ui.display.Effects
--- @field winhighlight? string[]
--- @field border? distant.core.ui.display.Border|string[]
--- @field width? distant.core.ui.display.WinWidth
--- @field height? distant.core.ui.display.WinHeight

--- @param size integer | float
--- @param viewport integer
local function calc_size(size, viewport)
    if size <= 1 then
        return math.ceil(size * viewport)
    end
    return math.min(size, viewport)
end

--- @param opts distant.core.ui.display.WindowOpts
--- @param sizes_only boolean #Whether to only return properties that control the window size.
local function create_popup_window_opts(opts, sizes_only)
    local lines = vim.o.lines - vim.o.cmdheight
    local columns = vim.o.columns
    local height = calc_size(opts.height or DEFAULT_UI_HEIGHT, lines)
    local width = calc_size(opts.width or DEFAULT_UI_WIDTH, columns)
    local row = math.floor((lines - height) / 2)
    local col = math.floor((columns - width) / 2)
    local popup_layout = {
        height = height,
        width = width,
        row = row,
        col = col,
        relative = 'editor',
        style = 'minimal',
        zindex = 45,
    }

    if not sizes_only then
        popup_layout.border = opts.border
    end

    return popup_layout
end

--- @alias distant.core.ui.display.RowColTuple {[1]:number, [2]:number}

--- This class represents a window to be rendered.
---
--- The setup process requires invoking several functions in a specific order:
--- 1. `window.view` - define how a window's state will be rendered visually.
--- 2. `window.state` - initialize window's state to be able to retrieve and mutate it.
--- 3. `window.init` - fully initialize the window.
---
--- @class distant.core.ui.display.Window
--- @field view fun(_renderer:fun(state:table):distant.core.ui.INode)
--- @field effects fun(_effects:table<string, fun()>)
--- @field state fun(initial_state:table):fun(mutate_fn:fun(current_state:table)),fun():table
--- @field init fun(opts:distant.core.ui.display.WindowOpts)
--- @field open fun()
--- @field close fun()
--- @field set_cursor fun(pos:distant.core.ui.display.RowColTuple) # (row, col) tuple
--- @field get_cursor fun():distant.core.ui.display.RowColTuple
--- @field is_open fun():boolean
--- @field set_sticky_cursor fun(tag:any)
--- @field get_win_config fun():table<string, any>
--- @field dispatch fun(effect:string, payload?:table)

--- @param name string #Human readable identifier.
--- @param filetype string
--- @return distant.core.ui.display.Window
function M.new_view_only_win(name, filetype)
    local namespace = vim.api.nvim_create_namespace(('%s_%s'):format(name, utils.next_id()))

    --- @type integer|nil
    local bufnr
    --- @type nil|fun(state:table):distant.core.ui.INode
    local renderer
    --- @type nil|fun(mutate_fn:fun(current_state:table))
    local mutate_state
    --- @type nil|fun():table
    local get_state
    --- @type nil|fun(val:boolean)
    local unsubscribe
    --- @type integer|nil
    local win_id
    --- @type number|nil, number|nil
    local window_mgmt_augroup, autoclose_augroup
    --- @type table<string, boolean>
    local registered_keymaps = {}
    --- @type table<number, table<string, distant.core.ui.display.RenderKeybind>>
    local registered_keybinds = {}
    --- @type distant.core.ui.display.Effects
    local registered_effect_handlers = {}
    --- @type string|nil
    local sticky_cursor

    local has_initiated = false
    --- @type distant.core.ui.display.WindowOpts
    local window_opts = {}

    vim.diagnostic.config({
        virtual_text = {
            severity = { min = vim.diagnostic.severity.HINT, max = vim.diagnostic.severity.ERROR },
        },
        right_align = false,
        underline = false,
        signs = false,
        virtual_lines = false,
    }, namespace)

    local function delete_win_buf()
        -- We queue the win_buf to be deleted in a schedule call, otherwise when used with folke/which-key (and
        -- set timeoutlen=0) we run into a weird segfault.
        -- It should probably be unnecessary once https://github.com/neovim/neovim/issues/15548 is resolved
        vim.schedule(function()
            if win_id and vim.api.nvim_win_is_valid(win_id) then
                log.trace('Deleting window')
                vim.api.nvim_win_close(win_id, true)
            end
            if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
                log.trace('Deleting buffer')
                vim.api.nvim_buf_delete(bufnr, { force = true })
            end
        end)
    end

    --- @param line number
    --- @param key string
    local function call_effect_handler(line, key)
        local line_keybinds = registered_keybinds[line]
        if line_keybinds then
            local keybind = line_keybinds[key]
            if keybind then
                local effect_handler = registered_effect_handlers[keybind.effect]
                if effect_handler then
                    log.fmt_trace('Calling handler for effect %s on line %d for key %s', keybind.effect, line, key)
                    effect_handler({ payload = keybind.payload })
                    return true
                end
            end
        end
        return false
    end

    local function dispatch_effect(key)
        local line = vim.api.nvim_win_get_cursor(0)[1]
        log.fmt_trace('Dispatching effect on line %d, key %s, bufnr %s', line, key, bufnr)
        call_effect_handler(line, key) -- line keybinds
        call_effect_handler(-1, key)   -- global keybinds
    end

    local output

    --- @param view distant.core.ui.INode
    local draw = function(view)
        local win_valid = win_id ~= nil and vim.api.nvim_win_is_valid(win_id)
        local buf_valid = bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr)

        --- @cast win_id integer
        --- @cast bufnr integer

        if not win_valid or not buf_valid then
            -- the window has been closed or the buffer is somehow no longer valid
            assert(unsubscribe ~= nil, 'unsubscribe is invalid during drawing of window')
            unsubscribe(true)
            log.trace('Buffer or window is no longer valid', win_id, bufnr)
            return
        end

        local win_width = vim.api.nvim_win_get_width(win_id)
        --- @class distant.core.ui.display.ViewportContext
        local viewport_context = {
            win_width = win_width,
        }
        local cursor_pos_pre_render = vim.api.nvim_win_get_cursor(win_id)
        if output then
            sticky_cursor = output.sticky_cursors.line_map[cursor_pos_pre_render[1]]
        end

        output = render_node(viewport_context, view)
        local lines, virt_texts, highlights, keybinds, diagnostics =
            output.lines, output.virt_texts, output.highlights, output.keybinds, output.diagnostics

        -- set line contents
        vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
        vim.api.nvim_buf_set_option(bufnr, 'modifiable', true)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
        vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)

        -- restore sticky cursor position
        if sticky_cursor then
            local new_sticky_cursor_line = output.sticky_cursors.id_map[sticky_cursor]
            if new_sticky_cursor_line and new_sticky_cursor_line ~= cursor_pos_pre_render then
                vim.api.nvim_win_set_cursor(win_id, { new_sticky_cursor_line, cursor_pos_pre_render[2] })
            end
        end

        -- set virtual texts
        for i = 1, #virt_texts do
            local virt_text = virt_texts[i]
            vim.api.nvim_buf_set_extmark(bufnr, namespace, virt_text.line, 0, {
                --- @type distant.core.ui.Span # (text, highlight) tuple
                virt_text = virt_text.content,
            })
        end

        -- set diagnostics
        vim.diagnostic.set(
            namespace,
            bufnr,
            --- @param diagnostic distant.core.ui.display.RenderDiagnostic
            vim.tbl_map(function(diagnostic)
                return {
                    lnum = diagnostic.line - 1,
                    col = 0,
                    message = diagnostic.message,
                    severity = diagnostic.severity,
                    source = diagnostic.source,
                }
            end, diagnostics),
            {
                signs = false,
            }
        )

        -- set highlights
        for i = 1, #highlights do
            local highlight = highlights[i]
            vim.api.nvim_buf_add_highlight(
                bufnr,
                namespace,
                highlight.hl_group,
                highlight.line,
                highlight.col_start,
                highlight.col_end
            )
        end

        -- set keybinds
        registered_keybinds = {}
        for i = 1, #keybinds do
            local keybind = keybinds[i]
            if not registered_keybinds[keybind.line] then
                registered_keybinds[keybind.line] = {}
            end
            registered_keybinds[keybind.line][keybind.key] = keybind
            if not registered_keymaps[keybind.key] then
                registered_keymaps[keybind.key] = true
                vim.keymap.set('n', keybind.key, function()
                    dispatch_effect(keybind.key)
                end, {
                    buffer = bufnr,
                    nowait = true,
                    silent = true,
                })
            end
        end
    end

    local function open()
        bufnr = vim.api.nvim_create_buf(false, true)
        win_id = vim.api.nvim_open_win(bufnr, true, create_popup_window_opts(window_opts, false))

        registered_effect_handlers = window_opts.effects or {}
        registered_keybinds = {}
        registered_keymaps = {}

        local buf_opts = {
            modifiable = false,
            swapfile = false,
            textwidth = 0,
            buftype = 'nofile',
            bufhidden = 'wipe',
            buflisted = false,
            filetype = filetype,
            undolevels = -1,
        }

        local win_opts = {
            number = false,
            relativenumber = false,
            wrap = false,
            spell = false,
            foldenable = false,
            signcolumn = 'no',
            colorcolumn = '',
            cursorline = true,
        }

        -- window options
        for key, value in pairs(win_opts) do
            vim.api.nvim_win_set_option(win_id, key, value)
        end

        if window_opts.winhighlight then
            vim.api.nvim_win_set_option(win_id, 'winhighlight', table.concat(window_opts.winhighlight, ','))
        end

        -- buffer options
        for key, value in pairs(buf_opts) do
            vim.api.nvim_buf_set_option(bufnr, key, value)
        end

        vim.cmd [[ syntax clear ]]

        window_mgmt_augroup = vim.api.nvim_create_augroup('DistantWindowMgmt', {})
        autoclose_augroup = vim.api.nvim_create_augroup('DistantWindow', {})

        vim.api.nvim_create_autocmd({ 'VimResized' }, {
            group = window_mgmt_augroup,
            buffer = bufnr,
            callback = function()
                if vim.api.nvim_win_is_valid(win_id) then
                    assert(renderer ~= nil, 'renderer is invalid during resize')
                    assert(get_state ~= nil, 'get_state is invalid during resize')
                    draw(renderer(get_state()))
                    vim.api.nvim_win_set_config(win_id, create_popup_window_opts(window_opts, true))
                end
            end,
        })

        vim.api.nvim_create_autocmd({ 'BufHidden', 'BufUnload' }, {
            group = autoclose_augroup,
            buffer = bufnr,
            callback = function()
                -- Schedule is done because otherwise the window won't actually close in some cases (for example if
                -- you're loading another buffer into it)
                vim.schedule(function()
                    if vim.api.nvim_win_is_valid(win_id) then
                        vim.api.nvim_win_close(win_id, true)
                    end
                end)
            end,
        })

        local win_enter_aucmd
        win_enter_aucmd = vim.api.nvim_create_autocmd({ 'WinEnter' }, {
            group = autoclose_augroup,
            pattern = '*',
            callback = function()
                local buftype = vim.api.nvim_buf_get_option(0, 'buftype')
                -- This allows us to keep the floating window open for things like diagnostic popups, UI inputs á la dressing.nvim, etc.
                if buftype ~= 'prompt' and buftype ~= 'nofile' then
                    delete_win_buf()
                    vim.api.nvim_del_autocmd(win_enter_aucmd)
                end
            end,
        })

        return win_id
    end

    return {
        --- Define how the window will be rendered.
        --- @param _renderer fun(state: table):distant.core.ui.INode
        view = function(_renderer)
            renderer = _renderer
        end,
        --- Update the effects for the next time the window is opened.
        --- @alias distant.core.ui.display.Effects table<string, distant.core.ui.display.EffectFn>
        --- @alias distant.core.ui.display.EffectFn fun(event?:{payload:any})
        --- @param _effects distant.core.ui.display.Effects
        effects = function(_effects)
            window_opts.effects = _effects
        end,
        --- @generic T : table
        --- @param initial_state T
        --- @return fun(mutate_fn: fun(current_state: T)), fun(): T
        state = function(initial_state)
            mutate_state, get_state, unsubscribe = state.create_state_container(
                initial_state,
                --- @param new_state table
                debounced(function(new_state)
                    assert(renderer ~= nil, 'renderer is invalid during drawing of state change')
                    draw(renderer(new_state))
                end)
            )

            -- we don't need to subscribe to state changes until the window is actually opened
            unsubscribe(true)

            return mutate_state, get_state
        end,
        --- @param opts distant.core.ui.display.WindowOpts
        init = function(opts)
            assert(renderer ~= nil, 'No view function has been registered. Call .view() before .init().')
            assert(unsubscribe ~= nil, 'No state has been registered. Call .state() before .init().')
            window_opts = opts
            has_initiated = true
        end,
        open = vim.schedule_wrap(function()
            log.trace('Opening window')
            assert(has_initiated, 'Display has not been initiated, cannot open.')
            if win_id and vim.api.nvim_win_is_valid(win_id) then
                -- window is already open
                return
            end

            assert(unsubscribe ~= nil, 'unsubscribe is invalid during opening of window')
            unsubscribe(false)

            open()

            assert(renderer ~= nil, 'renderer is invalid during opening of window')
            assert(get_state ~= nil, 'get_state is invalid during opening of window')
            draw(renderer(get_state()))
        end),
        --- @type fun()
        close = vim.schedule_wrap(function()
            assert(has_initiated, 'Display has not been initiated, cannot close.')
            assert(unsubscribe ~= nil, 'unsubscribe is invalid during closing of window')
            unsubscribe(true)
            log.fmt_trace('Closing window win_id=%s, bufnr=%s', win_id, bufnr)
            delete_win_buf()

            -- NOTE: These augroup ids should always be assigned as we do so during open()
            if window_mgmt_augroup ~= nil then
                vim.api.nvim_del_augroup_by_id(window_mgmt_augroup)
            end
            if autoclose_augroup ~= nil then
                vim.api.nvim_del_augroup_by_id(autoclose_augroup)
            end
        end),
        --- @param pos number[]: (row, col) tuple
        set_cursor = function(pos)
            assert(win_id ~= nil, 'Window has not been opened, cannot set cursor.')
            return vim.api.nvim_win_set_cursor(win_id, pos)
        end,
        --- @return number[]: (row, col) tuple
        get_cursor = function()
            assert(win_id ~= nil, 'Window has not been opened, cannot get cursor.')
            return vim.api.nvim_win_get_cursor(win_id)
        end,
        is_open = function()
            return win_id ~= nil and vim.api.nvim_win_is_valid(win_id)
        end,
        --- @param tag string
        set_sticky_cursor = function(tag)
            if output then
                local new_sticky_cursor_line = output.sticky_cursors.id_map[tag]
                if new_sticky_cursor_line then
                    sticky_cursor = tag

                    -- TODO: Should we throw an assertion error here instead?
                    if win_id ~= nil then
                        local cursor = vim.api.nvim_win_get_cursor(win_id)
                        vim.api.nvim_win_set_cursor(win_id, { new_sticky_cursor_line, cursor[2] })
                    end
                end
            end
        end,
        get_win_config = function()
            assert(win_id ~= nil, 'Window has not been opened, cannot get config.')
            return vim.api.nvim_win_get_config(win_id)
        end,

        --- @param effect string
        --- @param payload? table
        dispatch = vim.schedule_wrap(function(effect, payload)
            local effect_handler = registered_effect_handlers[effect]
            if effect_handler then
                log.fmt_trace('Calling handler for effect %s through direct dispatch', name)
                effect_handler({ payload = payload })
                return true
            end
        end),
    }
end

return M
