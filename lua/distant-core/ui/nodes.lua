local M = {}

--- @alias distant.core.ui.NodeType
--- | '"NODE"'
--- | '"CASCADING_STYLE"'
--- | '"VIRTUAL_TEXT"'
--- | '"DIAGNOSTICS"'
--- | '"HL_TEXT"'
--- | '"KEYBIND_HANDLER"'
--- | '"STICKY_CURSOR"'

--- @alias distant.core.ui.INode
--- | distant.core.ui.Node
--- | distant.core.ui.HlTextNode
--- | distant.core.ui.CascadingStyleNode
--- | distant.core.ui.VirtualTextNode
--- | distant.core.ui.KeybindHandlerNode
--- | distant.core.ui.DiagnosticsNode
--- | distant.core.ui.StickyCursorNode

--- Creates a node that acts as a container for other nodes.
--- @param children distant.core.ui.INode[]
--- @return distant.core.ui.Node
function M.Node(children)
    --- @class distant.core.ui.Node
    local node = {
        type = 'NODE',
        --- @type distant.core.ui.INode[]
        children = children,
    }
    return node
end

--- @alias distant.core.ui.Span
--- | { [1]:string, [2]:string } # tuple (content, hl_group)

--- Creates a node that will render text across one or more lines.
--- The text is rendered using spans, which are tuples comprised
--- of some text and a highlight group (or empty string for no highlight).
---
--- For example:
---
--- ```
--- ui.HlTextNode {
---     -- First line will render with bold text in the middle
---     {
---         {'some regular text ', ''},
---         {'with bold words', 'MyBoldHlGroup'},
---         {' mixed in', ''},
---     },
---     -- Second line will render with regular text only
---     {
---         {'with another line that is regular text', ''},
---     },
--- }
--- ```
---
--- Another example:
---
--- ```
--- ui.HlTextNode { 'some bold text', 'MyBoldHlGroup' }
--- ```
---
--- @param lines_with_span_tuples distant.core.ui.Span|distant.core.ui.Span[][]
--- @return distant.core.ui.HlTextNode
function M.HlTextNode(lines_with_span_tuples)
    -- If given single span, we convert it into distant.core.ui.Span[][].
    --
    -- This enables a convenience API for just rendering a
    -- single line (with just a single span).
    if type(lines_with_span_tuples[1]) == 'string' then
        --- @cast lines_with_span_tuples distant.core.ui.Span
        lines_with_span_tuples = { { lines_with_span_tuples } }
    end

    --- @class distant.core.ui.HlTextNode
    local node = {
        type = 'HL_TEXT',
        --- Array of lines, where each line is an array of spans
        --- representing that line.
        ---
        --- @type distant.core.ui.Span[][]
        lines = lines_with_span_tuples,
    }
    return node
end

--- Converts a series of lines into a series of spans
--- where the highlight group is empty.
---
--- @param lines string[]
--- @return distant.core.ui.Span[][] # List of tuples being (line, blank str)
local function create_unhighlighted_lines(lines)
    local unhighlighted_lines = {}

    -- For each line, we create a single span
    for _, line in ipairs(lines) do
        table.insert(unhighlighted_lines, { { line, '' } })
    end

    return unhighlighted_lines
end

--- @param lines string[]
--- @return distant.core.ui.HlTextNode
function M.Text(lines)
    return M.HlTextNode(create_unhighlighted_lines(lines))
end

--- @alias distant.core.ui.CascadingStyle
---| '"INDENT"'
---| '"CENTERED"'

--- Creates a node that will apply one or more styles to all of
--- the provided `children` nodes.
---
--- @param styles distant.core.ui.CascadingStyle[]
--- @param children distant.core.ui.INode[]
function M.CascadingStyleNode(styles, children)
    --- @class distant.core.ui.CascadingStyleNode
    local node = {
        type = 'CASCADING_STYLE',
        --- @type distant.core.ui.CascadingStyle[]
        styles = styles,
        --- @type distant.core.ui.INode[]
        children = children,
    }
    return node
end

--- Creates a node that will set virtual text similar to
--- `vim.api.nvim_buf_set_extmark` on the the last physical line
--- prior to this node.
---
--- @param virt_text distant.core.ui.Span[] List of (text, highlight) tuples.
--- @return distant.core.ui.VirtualTextNode
function M.VirtualTextNode(virt_text)
    --- @class distant.core.ui.VirtualTextNode
    local node = {
        type = 'VIRTUAL_TEXT',
        --- @type distant.core.ui.Span[]
        virt_text = virt_text,
    }
    return node
end

--- @class distant.core.ui.Diagnostic
--- @field message string
--- @field severity integer
--- @field source? string

--- Creates a node that will set diagnostics similar to
--- `vim.diagnostic.set` on the the last physical line
--- prior to this node.
---
--- @param diagnostic distant.core.ui.Diagnostic
--- @return distant.core.ui.DiagnosticsNode
function M.DiagnosticsNode(diagnostic)
    --- @class distant.core.ui.DiagnosticsNode
    local node = {
        type = 'DIAGNOSTICS',
        --- @type distant.core.ui.Diagnostic
        diagnostic = diagnostic,
    }
    return node
end

--- If the `condition` is true, the `node` will be returned. Otherwise,
--- if a `default_val` is provided, it will be returned. If no `default_val`
--- is provided, then an empty node will be returned instead.
---
--- @param condition boolean
--- @param node distant.core.ui.INode | fun():distant.core.ui.INode
--- @param default_val any
function M.When(condition, node, default_val)
    if condition then
        if type(node) == 'function' then
            return node()
        else
            return node
        end
    end
    return default_val or M.Node {}
end

--- Creates a node that does not render anything visually, but rather defines
--- a new keybinding that the user can perform. This will in turn trigger
--- an effect. The effect needs to be specified via the `window.effect`
--- function, which will register it with the window. The `payload` will
--- be passed to the registered effect.
---
--- By default, a keybinding is NOT global, which means that it will only
--- trigger relative to the last physical line.
---
--- ```
--- -- Creates a node comprised of multiple lines
--- ui.Node {
---     ui.HlTextNode {...}, -- Represents one or more lines
---     ui.Keybind {...},    -- Applies to last line of above (not all of them)
--- }
--- ```
---
--- Presently, only the `HlTextNode` is a physical line, meaning that it
--- will render in some way one or more lines.
---
--- @param key string # The keymap to register to. Example: '<CR>'.
--- @param effect string # The effect to call when keymap is triggered by the user.
--- @param payload any # The payload to pass to the effect handler when triggered.
--- @param is_global boolean? # Whether to register the keybind to apply on all lines in the buffer. (default false)
--- @return distant.core.ui.KeybindHandlerNode
function M.Keybind(key, effect, payload, is_global)
    --- @class distant.core.ui.KeybindHandlerNode
    local node = {
        type = 'KEYBIND_HANDLER',
        --- @type string
        key = key,
        --- @type string
        effect = effect,
        --- @type any
        payload = payload,
        --- @type boolean
        is_global = is_global or false,
    }
    return node
end

--- @return distant.core.ui.HlTextNode
function M.EmptyLine()
    return M.Text({ '' })
end

--- Creates a node with a table layout.
---
--- Each row consists of an array of (text, highlight) tuples (aka spans)
--- that represent the columns. The rows do NOT need to have the same number
--- of columns.
---
--- The table will auto-align and provide padding to fit the biggest
--- value within each column across all rows.
---
--- For example:
---
--- ```
--- ui.Table {
---     -- First row would usually be a header
---     {
---         {'My Header', 'BoldHlGroup'},
---     },
---     -- Rest of the rows would usually be data
---     {
---         {'First Col', ''},
---         {'Second Col', ''},
---         {'Third Col', ''},
---     },
---     {
---         {'First Col', ''},
---         {'Second Col', ''},
---     },
--- }
--- ```
---
--- @param rows distant.core.ui.Span[][]
--- @param extra? {[integer]: distant.core.ui.INode[]} # additional nodes to attach after a specific row
--- @return distant.core.ui.INode
function M.Table(rows, extra)
    local col_maxwidth = {}
    for i = 1, #rows do
        local row = rows[i]
        for j = 1, #row do
            local col = row[j]
            local content = col[1]
            col_maxwidth[j] = math.max(vim.api.nvim_strwidth(content), col_maxwidth[j] or 0)
        end
    end

    for i = 1, #rows do
        local row = rows[i]
        for j = 1, #row do
            local col = row[j]
            local content = col[1]
            col[1] = content ..
                string.rep(' ', col_maxwidth[j] - vim.api.nvim_strwidth(content) + 1) -- +1 for default minimum padding
        end
    end

    -- For neovim 0.10+, `tbl_isarray` is the new `tbl_islist` whereas on earlier versions
    -- there is no `tbl_isarray`; so, check if we have the new function and use it otherwise
    -- fall back to the old function.
    local isarray = vim.tbl_isarray or vim.tbl_islist

    if type(extra) == 'table' and isarray(extra) then
        --- @type distant.core.ui.INode[]
        local rows_with_extra = {}

        -- For each row, we are going to construct a singular
        -- visual line and then augment it with the extra nodes
        for i = 1, #rows do
            --- @type distant.core.ui.INode[]
            local row = {}

            -- First, add the row itself as a single-line visual node
            table.insert(row, M.HlTextNode { rows[i] })

            -- Second, add all other nodes for this row to the list
            local extra_cnt = 0
            if type(extra[i]) == 'table' then
                extra_cnt = #extra[i]
            end

            for j = 1, extra_cnt do
                table.insert(row, extra[i][j])
            end

            -- Third, add row as a node
            table.insert(rows_with_extra, M.Node(row))
        end

        return M.Node(rows_with_extra)
    else
        return M.HlTextNode(rows)
    end
end

--- Creates a node that assigns `opts.id` to the last physical line prior to this node.
---
--- When using `window.set_sticky_cursor`, this will jump the cursor back to the position
--- where the sticky cursor was defined if it is still visible.
---
--- @param opts { id: string }
--- @return distant.core.ui.StickyCursorNode
function M.StickyCursor(opts)
    --- @class distant.core.ui.StickyCursorNode
    local node = {
        type = 'STICKY_CURSOR',
        --- @type string
        id = opts.id,
    }
    return node
end

return M
