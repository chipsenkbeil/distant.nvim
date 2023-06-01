local log = require('distant-core.log')
local init_state = require('distant-core.ui.init_state')
local utils = require('distant-core.utils')

--- @alias distant.core.ui.window.Width number
--- Width of the window. Accepts:
--- - Integer greater than 1 for fixed width.
--- - Float in the range of 0-1 for a percentage of screen width.

--- @alias distant.core.ui.window.Height number
--- Height of the window. Accepts:
--- - Integer greater than 1 for fixed height.
--- - Float in the range of 0-1 for a percentage of screen height.

--- @type distant.core.ui.window.Width
local DEFAULT_UI_WIDTH = 0.8

--- @type distant.core.ui.window.Height
local DEFAULT_UI_HEIGHT = 0.9

--- Wraps `debounced_fn` to schedule its execution using `vim.schedule`.
---
--- In the situation where the resulting function is invoked before the
--- previous call finishes executing, the new call is ignored.
---
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
--- @param render_context distant.core.ui.window.RenderContext
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

--- @param viewport_context distant.core.ui.window.ViewportContext
--- @param node distant.core.ui.INode
--- @param _render_context? distant.core.ui.window.RenderContext
--- @param _output? distant.core.ui.window.RenderOutput
--- @return distant.core.ui.window.RenderOutput
local function render_node(viewport_context, node, _render_context, _output)
    --- @class distant.core.ui.window.RenderContext
    --- @field viewport_context distant.core.ui.window.ViewportContext
    --- @field applied_block_styles distant.core.ui.CascadingStyle[][]
    local render_context = _render_context
        or {
            viewport_context = viewport_context,
            applied_block_styles = {},
        }
    --- @class distant.core.ui.window.RenderHighlight
    --- @field hl_group string
    --- @field line number
    --- @field col_start number
    --- @field col_end number

    --- @class distant.core.ui.window.RenderKeybind
    --- @field line number
    --- @field key string
    --- @field effect string
    --- @field payload any

    --- @class distant.core.ui.window.RenderDiagnostic
    --- @field line number
    --- @field message string
    --- @field severity integer
    --- @field source? string

    --- @class distant.core.ui.window.RenderOutput
    --- @field lines string[]: The buffer lines.
    --- @field virt_texts {line: integer, content: distant.core.ui.Span}[]: List of tuples.
    --- @field highlights distant.core.ui.window.RenderHighlight[]
    --- @field keybinds distant.core.ui.window.RenderKeybind[]
    --- @field diagnostics distant.core.ui.window.RenderDiagnostic[]
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

--- @alias distant.core.ui.window.Border
--- | '"none"'      # no border (default)
--- | '"single"'    # a single line box
--- | '"double"'    # a double line box
--- | '"rounded"'   # like "single", but with rounded corners
--- | '"solid"'     # adds padding by a single whitespace cell
--- | '"shadow"'    # a drop shadow effect by blending with the background

--- @class distant.core.ui.window.WindowOpts
--- @field winhighlight? string[]
--- @field border? distant.core.ui.window.Border|string[]
--- @field width? distant.core.ui.window.Width
--- @field height? distant.core.ui.window.Height

--- @param size integer | float
--- @param viewport integer
local function calc_size(size, viewport)
    if size <= 1 then
        return math.ceil(size * viewport)
    end
    return math.min(size, viewport)
end

--- @param opts distant.core.ui.window.WindowOpts
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

--------------------------------------------------------------------------
-- WINDOW CLASS DEFINITION
--------------------------------------------------------------------------

--- @alias distant.core.ui.window.RowColTuple {[1]:number, [2]:number}
--- @alias distant.core.ui.window.Effects table<string, distant.core.ui.window.EffectFn>
--- @alias distant.core.ui.window.EffectFn fun(event:distant.core.ui.window.EffectEvent)
--- @alias distant.core.ui.window.EffectEvent {state:distant.core.ui.window.State, window:distant.core.ui.Window, payload:any}

--- @class distant.core.ui.window.State
--- @field mutate fun(mutate_fn:fun(current_state:table))
--- @field get fun():table
--- @field __unsubscribe fun(val:boolean)

--- This class represents a window to be rendered.
---
--- The setup process requires invoking several functions in a specific order:
--- 1. `window.view` - define how a window's state will be rendered visually.
--- 2. `window.state` - initialize window's state to be able to retrieve and mutate it.
--- 3. `window.init` - fully initialize the window.
---
--- @class distant.core.ui.Window
--- @field state distant.core.ui.window.State
---
--- @field private __namespace number
--- @field private __filetype filetype
--- @field private __registered_keymaps table<string, boolean>
--- @field private __registered_keybindings table<number, table<string, distant.core.ui.window.RenderKeybind>>
--- @field private __registered_effect_handlers distant.core.ui.window.Effects
--- @field private __renderer fun(state:table):distant.core.ui.INode
--- @field private __effects distant.core.ui.window.Effects
--- @field private __winopts distant.core.ui.window.WindowOpts
---
--- @field private __window_mgmt_augroup? number
--- @field private __autoclose_augroup? number
--- @field private __sticky_cursor? string
--- @field private __buf? number
--- @field private __win? number
--- @field private __output? distant.core.ui.window.RenderOutput
local M = {}
M.__index = M

--- @class distant.core.ui.window.NewOpts
--- @field name string
--- @field filetype string
--- @field view fun(state:table):distant.core.ui.INode
--- @field effects? distant.core.ui.window.Effects # initial effects to assign to the window
--- @field initial_state? table # optional initial value of state, defaulting to {}
--- @field winopts? distant.core.ui.window.WindowOpts # optional window-specific options

--- Creates a new window.
--- @param opts distant.core.ui.window.NewOpts
--- @return distant.core.ui.Window
function M:new(opts)
    local instance = {}
    setmetatable(instance, M)

    --------------------------------------------------------------------------
    -- SET PRIVATE VARIABLES
    --------------------------------------------------------------------------

    instance.__namespace = vim.api.nvim_create_namespace(('%s_%s'):format(
        assert(opts.name, 'Missing name for window'),
        utils.next_id()
    ))
    instance.__filetype = assert(opts.filetype, 'Missing filetype for window')
    instance.__renderer = assert(opts.view, 'Missing view definition for window')
    instance.__registered_keymaps = {}
    instance.__registered_keybindings = {}
    instance.__registered_effect_handlers = {}
    instance.__effects = vim.deepcopy(opts.effects or {})
    instance.__winopts = vim.deepcopy(opts.winopts or {})

    --------------------------------------------------------------------------
    -- CONFIGURE DIAGNOSTICS
    --------------------------------------------------------------------------

    vim.diagnostic.config({
        virtual_text = {
            severity = { min = vim.diagnostic.severity.HINT, max = vim.diagnostic.severity.ERROR },
        },
        right_align = false,
        underline = false,
        signs = false,
        virtual_lines = false,
    }, self.__namespace)

    --------------------------------------------------------------------------
    -- INITIALIZE STATE
    --------------------------------------------------------------------------

    local mutate_state, get_state, unsubscribe = init_state(
        opts.initial_state or {},
        --- @param new_state table
        debounced(function(new_state)
            instance:__draw(instance.__renderer(new_state))
        end)
    )

    -- we don't need to subscribe to state changes until the window is actually opened
    unsubscribe(true)

    instance.state = {
        mutate = mutate_state,
        get = get_state,
        __unsubscribe = unsubscribe,
    }

    --------------------------------------------------------------------------
    -- RETURN NEW WINDOW
    --------------------------------------------------------------------------

    return instance
end

-------------------------------------------------------------------------------
-- PUBLIC API
-------------------------------------------------------------------------------

--- Opens the window if not open already.
function M:open()
    vim.schedule(function()
        log.trace('Opening window')

        if self.__win and vim.api.nvim_win_is_valid(self.__win) then
            -- window is already open
            return
        end

        self.state.__unsubscribe(false)
        self:__open()

        -- Draw immediately after opening to make sure the content is visible
        self:redraw({ immediate = true })

        -- NOTE: We schedule one redraw after the initial draw
        --       to capture state changes that happen shortly
        --       after opening
        self:redraw()
    end)
end

--- Closes the window if open.
function M:close()
    vim.schedule(function()
        log.fmt_trace('Closing window win_id=%s, bufnr=%s', self.__win, self.__buf)

        self.state.__unsubscribe(true)
        self:__delete_win_buf()

        -- NOTE: These augroup ids should always be assigned as we do so during open()
        if self.__window_mgmt_augroup ~= nil then
            vim.api.nvim_del_augroup_by_id(self.__window_mgmt_augroup)
        end
        if self.__autoclose_augroup ~= nil then
            vim.api.nvim_del_augroup_by_id(self.__autoclose_augroup)
        end
    end)
end

--- Force the window to redraw its contents. Does nothing if the window is not open.
---
--- ### Options
---
--- * `immediate` - if true, will draw immediately instead of scheduling a draw.
---
--- @param opts? {immediate?:boolean}
function M:redraw(opts)
    if not self:is_open() then
        return
    end

    opts = opts or {}

    local function draw()
        self:__draw(self.__renderer(self.state.get()))
    end

    if opts.immediate then
        draw()
    else
        vim.schedule(draw)
    end
end

--- Sets the cursor position within the open window.
---
--- If the window is not open, this will throw an error!
---
--- @param pos number[] # (row, col) tuple
function M:set_cursor(pos)
    assert(self.__win ~= nil, 'Window has not been opened, cannot set cursor.')
    return vim.api.nvim_win_set_cursor(self.__win, pos)
end

--- Retrieves the cursor position within the open window.
---
--- If the window is not open, this will throw an error!
---
--- @return number[] # (row, col) tuple
function M:get_cursor()
    assert(self.__win ~= nil, 'Window has not been opened, cannot get cursor.')
    return vim.api.nvim_win_get_cursor(self.__win)
end

--- Returns whether or not the window is currently open and valid.
--- @return boolean
function M:is_open()
    return self.__win ~= nil and vim.api.nvim_win_is_valid(self.__win)
end

--- Jumps cursor within the open window to the location marked by the `tag`.
--- @param tag string
function M:set_sticky_cursor(tag)
    if self.__output then
        local new_sticky_cursor_line = self.__output.sticky_cursors.id_map[tag]
        if new_sticky_cursor_line then
            self.__sticky_cursor = tag

            if self.__win ~= nil then
                local cursor = vim.api.nvim_win_get_cursor(self.__win)
                vim.api.nvim_win_set_cursor(self.__win, { new_sticky_cursor_line, cursor[2] })
            end
        end
    end
end

--- Retrieves the neovim configuration tied to the window.
---
--- If the window is not open, this will throw an error!
---
--- @return table<string, any>
function M:win_config()
    assert(self.__win ~= nil, 'Window has not been opened, cannot get config.')
    return vim.api.nvim_win_get_config(self.__win)
end

--- Updates window-specific options tied to this window.
--- @param opts distant.core.ui.window.WindowOpts
function M:set_winopts(opts)
    self.__winopts = opts
end

--- Returns window-specific options tied to this window.
--- @return distant.core.ui.window.WindowOpts
function M:winopts()
    return vim.deepcopy(self.__winopts)
end

--- Triggers an effect directly (versus with keybindings).
--- @param effect string # name of the effect
--- @param payload? any # optional payload to send to the effect, available as the `payload` field
function M:dispatch(effect, payload)
    vim.schedule(function()
        local effect_handler = self.__registered_effect_handlers[effect]
        if effect_handler then
            log.fmt_trace('Calling handler for effect %s through direct dispatch', effect)
            effect_handler({
                payload = payload,
                state = self.state,
                window = self,
            })
        end
    end)
end

--- Registers an effect with the window.
---
--- Note that this will only apply to future opening of the window, not
--- while it is presently open!
---
--- @param effect string
--- @param handler distant.core.ui.window.EffectFn
function M:register_effect(effect, handler)
    self.__effects[effect] = handler
end

--- Unregisters an effect with the window.
---
--- Note that this will only apply to future opening of the window, not
--- while it is presently open!
---
--- @param effect string
function M:unregister_effect(effect)
    self.__effects[effect] = nil
end

--- Mutates the state of the window. Convenience for `window.state.mutate(...)`.
--- @param mutate_fn fun(current_state:table)
function M:mutate_state(mutate_fn)
    self.state.mutate(mutate_fn)
end

--- Returns the state of the window. Convenience for `window.state.get()`.
--- @return table
function M:get_state()
    return self.state.get()
end

-------------------------------------------------------------------------------
-- PRIVATE API
-------------------------------------------------------------------------------

--- @private
function M:__delete_win_buf()
    -- We queue the win_buf to be deleted in a schedule call, otherwise when used with folke/which-key (and
    -- set timeoutlen=0) we run into a weird segfault.
    -- It should probably be unnecessary once https://github.com/neovim/neovim/issues/15548 is resolved
    vim.schedule(function()
        if self.__win and vim.api.nvim_win_is_valid(self.__win) then
            log.trace('Deleting window')
            vim.api.nvim_win_close(self.__win, true)
        end
        if self.__buf and vim.api.nvim_buf_is_valid(self.__buf) then
            log.trace('Deleting buffer')
            vim.api.nvim_buf_delete(self.__buf, { force = true })
        end
    end)
end

--- @private
--- @param line number
--- @param key string
function M:__call_effect_handler(line, key)
    local line_keybinds = self.__registered_keybinds[line]
    if line_keybinds then
        local keybind = line_keybinds[key]
        if keybind then
            local effect_handler = self.__registered_effect_handlers[keybind.effect]
            if effect_handler then
                log.fmt_trace('Calling handler for effect %s on line %d for key %s', keybind.effect, line, key)
                effect_handler({
                    payload = keybind.payload,
                    state = self.state,
                    window = self,
                })
                return true
            end
        end
    end
    return false
end

--- @private
--- @param key string
function M:__dispatch_effect(key)
    local line = vim.api.nvim_win_get_cursor(0)[1]
    log.fmt_trace('Dispatching effect on line %d, key %s, bufnr %s', line, key, self.__buf)
    self:__call_effect_handler(line, key) -- line keybinds
    self:__call_effect_handler(-1, key)   -- global keybinds
end

--- @private
--- @param view distant.core.ui.INode
function M:__draw(view)
    local win_valid = self.__win ~= nil and vim.api.nvim_win_is_valid(self.__win)
    local buf_valid = self.__buf ~= nil and vim.api.nvim_buf_is_valid(self.__buf)

    if not win_valid or not buf_valid then
        -- the window has been closed or the buffer is somehow no longer valid
        self.state.__unsubscribe(true)
        log.trace('Buffer or window is no longer valid', self.__win, self.__buf)
        return
    end

    local win_width = vim.api.nvim_win_get_width(self.__win)
    --- @class distant.core.ui.window.ViewportContext
    local viewport_context = {
        win_width = win_width,
    }
    local cursor_pos_pre_render = vim.api.nvim_win_get_cursor(self.__win)
    if self.__output then
        self.__sticky_cursor = self.__output.sticky_cursors.line_map[cursor_pos_pre_render[1]]
    end

    self.__output = render_node(viewport_context, view)
    local lines, virt_texts, highlights, keybinds, diagnostics =
        self.__output.lines, self.__output.virt_texts, self.__output.highlights, self.__output.keybinds,
        self.__output.diagnostics

    -- set line contents
    vim.api.nvim_buf_clear_namespace(self.__buf, self.__namespace, 0, -1)
    vim.api.nvim_buf_set_option(self.__buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(self.__buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(self.__buf, 'modifiable', false)

    -- restore sticky cursor position
    if self.__sticky_cursor then
        local new_sticky_cursor_line = self.__output.sticky_cursors.id_map[self.__sticky_cursor]
        if new_sticky_cursor_line and new_sticky_cursor_line ~= cursor_pos_pre_render then
            vim.api.nvim_win_set_cursor(self.__win, { new_sticky_cursor_line, cursor_pos_pre_render[2] })
        end
    end

    -- set virtual texts
    for i = 1, #virt_texts do
        local virt_text = virt_texts[i]
        vim.api.nvim_buf_set_extmark(self.__buf, self.__namespace, virt_text.line, 0, {
            --- @type distant.core.ui.Span # (text, highlight) tuple
            virt_text = virt_text.content,
        })
    end

    -- set diagnostics
    vim.diagnostic.set(
        self.__namespace,
        self.__buf,
        --- @param diagnostic distant.core.ui.window.RenderDiagnostic
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
            self.__buf,
            self.__namespace,
            highlight.hl_group,
            highlight.line,
            highlight.col_start,
            highlight.col_end
        )
    end

    -- set keybinds
    self.__registered_keybinds = {}
    for i = 1, #keybinds do
        local keybind = keybinds[i]
        if not self.__registered_keybinds[keybind.line] then
            self.__registered_keybinds[keybind.line] = {}
        end
        self.__registered_keybinds[keybind.line][keybind.key] = keybind
        if not self.__registered_keymaps[keybind.key] then
            self.__registered_keymaps[keybind.key] = true
            vim.keymap.set('n', keybind.key, function()
                self:__dispatch_effect(keybind.key)
            end, {
                buffer = self.__buf,
                nowait = true,
                silent = true,
            })
        end
    end
end

--- @private
function M:__open()
    self.__buf = vim.api.nvim_create_buf(false, true)
    self.__win = vim.api.nvim_open_win(self.__buf, true, create_popup_window_opts(self.__winopts, false))

    self.__registered_effect_handlers = vim.deepcopy(self.__effects)
    self.__registered_keybinds = {}
    self.__registered_keymaps = {}

    local buf_opts = {
        modifiable = false,
        swapfile = false,
        textwidth = 0,
        buftype = 'nofile',
        bufhidden = 'wipe',
        buflisted = false,
        filetype = self.__filetype,
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
        vim.api.nvim_win_set_option(self.__win, key, value)
    end

    if self.__winopts.winhighlight then
        vim.api.nvim_win_set_option(self.__win, 'winhighlight', table.concat(self.__winopts.winhighlight, ','))
    end

    -- buffer options
    for key, value in pairs(buf_opts) do
        vim.api.nvim_buf_set_option(self.__buf, key, value)
    end

    vim.cmd [[ syntax clear ]]

    -- Create augroups that are unique to this window (avoid clashing/deleting another augroup)
    self.__window_mgmt_augroup = vim.api.nvim_create_augroup('DistantWindowMgmt_' .. tostring(utils.next_id()), {})
    self.__autoclose_augroup = vim.api.nvim_create_augroup('DistantWindow_' .. tostring(utils.next_id()), {})

    vim.api.nvim_create_autocmd({ 'VimResized' }, {
        group = self.__window_mgmt_augroup,
        buffer = self.__buf,
        callback = function()
            if vim.api.nvim_win_is_valid(self.__win) then
                self:__draw(self.__renderer(self.state.get()))
                vim.api.nvim_win_set_config(self.__win, create_popup_window_opts(self.__winopts, true))
            end
        end,
    })

    vim.api.nvim_create_autocmd({ 'BufHidden', 'BufUnload' }, {
        group = self.__autoclose_augroup,
        buffer = self.__buf,
        callback = function()
            -- Schedule is done because otherwise the window won't actually close in some cases (for example if
            -- you're loading another buffer into it)
            vim.schedule(function()
                if vim.api.nvim_win_is_valid(self.__win) then
                    vim.api.nvim_win_close(self.__win, true)
                end
            end)
        end,
    })

    local win_enter_aucmd
    win_enter_aucmd = vim.api.nvim_create_autocmd({ 'WinEnter' }, {
        group = self.__autoclose_augroup,
        pattern = '*',
        callback = function()
            local buftype = vim.api.nvim_buf_get_option(0, 'buftype')
            -- This allows us to keep the floating window open for things like diagnostic popups, UI inputs á la dressing.nvim, etc.
            if buftype ~= 'prompt' and buftype ~= 'nofile' then
                self:__delete_win_buf()
                vim.api.nvim_del_autocmd(win_enter_aucmd)
            end
        end,
    })

    return self.__win
end

return M
