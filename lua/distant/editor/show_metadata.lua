local fn = require('distant.fn')
local log = require('distant-core').log

local p = require('distant.ui.palette')
local Ui = require('distant-core.ui')
local display = require('distant-core.ui.display')

-------------------------------------------------------------------------------
-- WINDOW DEFINITION
-------------------------------------------------------------------------------

--- @class distant.editor.show.metadata.State
local INITIAL_STATE = {
    --- @type string|nil
    path = nil,
    --- @type distant.core.api.MetadataPayload|nil
    metadata = nil,
}

local window = display.new_view_only_win('Metadata', 'distant')
local mutate_state, get_state = window.state(INITIAL_STATE)

--- @param state distant.editor.show.metadata.State
window.view(function(state)
    local path, metadata = state.path, state.metadata

    local table_view =
        Ui.When(path ~= nil and metadata ~= nil, function()
            assert(path)
            assert(metadata)

            local rows = {}
            table.insert(rows, { key = 'Name', value = 'Value', header = true })
            table.insert(rows, { key = 'Path', value = path })

            if metadata.canonicalized_path then
                table.insert(rows, {
                    key = 'Canonicalized Path',
                    value = metadata.canonicalized_path,
                })
            end

            table.insert(rows, { key = 'File Type', value = metadata.file_type })
            table.insert(rows, { key = 'File Size', value = tostring(metadata.len) .. ' bytes' })
            table.insert(rows, { key = 'Readonly', value = tostring(metadata.readonly) })

            if metadata.created ~= nil then
                table.insert(rows, {
                    key = 'Created',
                    value = vim.fn.strftime(
                        '%c',
                        math.floor(metadata.created / 1000.0)
                    ),
                })
            end
            if metadata.accessed ~= nil then
                table.insert(rows, {
                    key = 'Last Accessed',
                    value = vim.fn.strftime(
                        '%c',
                        math.floor(metadata.accessed / 1000.0)
                    ),
                })
            end
            if metadata.modified ~= nil then
                table.insert(rows, {
                    key = 'Last Modified',
                    value = vim.fn.strftime(
                        '%c',
                        math.floor(metadata.modified / 1000.0)
                    ),
                })
            end

            local function row_to_span(row)
                if row.header then
                    return {
                        p.Bold(row.key),
                        p.Bold(row.value),
                    }
                else
                    return {
                        p.muted(row.key),
                        p.highlight(row.value),
                    }
                end
            end

            return Ui.Table(vim.tbl_map(row_to_span, rows))
        end)

    local loading_view =
        Ui.When(metadata == nil, function()
            return Ui.Text({ 'Loading metadata...' })
        end)

    return Ui.Node {
        Ui.Keybind('q', 'CLOSE_WINDOW', nil, true),
        Ui.Keybind('<Esc>', 'CLOSE_WINDOW', nil, true),
        Ui.CascadingStyleNode({ 'INDENT' }, {
            Ui.EmptyLine(),
            loading_view,
            table_view,
        }),
    }
end)

window.init({
    effects = {
        ['CLOSE_WINDOW'] = function()
            mutate_state(function(state)
                state.path = nil
                state.metadata = nil
            end)
            window.close()
        end,
    },
    border = 'single',
    winhighlight = {
        'NormalFloat:DistantNormal',
    },
    width = 0.4,
    height = 0.3,
})

-------------------------------------------------------------------------------
-- OPEN WINDOW
-------------------------------------------------------------------------------

--- Opens a new window to show metadata for some path.
--- @param opts distant.core.api.MetadataOpts
return function(opts)
    opts = opts or {}
    local path = opts.path
    if not path then
        error('opts.path is missing')
    end
    log.fmt_trace('editor.show.metadata(%s)', opts)

    window.open()

    --- @param state distant.editor.show.metadata.State
    mutate_state(function(state)
        state.path = opts.path
    end)

    local err, metadata = fn.metadata(opts)

    if err then
        window.close()
    end

    assert(not err, tostring(err))
    assert(metadata)

    --- @param state distant.editor.show.metadata.State
    mutate_state(function(state)
        state.path = opts.path
        state.metadata = metadata
    end)
end
