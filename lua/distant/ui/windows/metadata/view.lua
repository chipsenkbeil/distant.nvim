local p  = require('distant.ui.palette')
local ui = require('distant-core.ui')

--- @param state distant.plugin.ui.windows.metadata.State
return function(state)
    local path, metadata = state.path, state.metadata

    local table_view =
        ui.When(path ~= nil and metadata ~= nil, function()
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
                    value = vim.fn.strftime('%c', metadata.created),
                })
            end
            if metadata.accessed ~= nil then
                table.insert(rows, {
                    key = 'Last Accessed',
                    value = vim.fn.strftime('%c', metadata.accessed),
                })
            end
            if metadata.modified ~= nil then
                table.insert(rows, {
                    key = 'Last Modified',
                    value = vim.fn.strftime('%c', metadata.modified),
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

            return ui.Table(vim.tbl_map(row_to_span, rows))
        end)

    local loading_view =
        ui.When(metadata == nil, function()
            return ui.Text({ 'Loading metadata...' })
        end)

    return ui.Node {
        ui.Keybind('q', 'CLOSE_WINDOW', nil, true),
        ui.Keybind('<Esc>', 'CLOSE_WINDOW', nil, true),
        ui.CascadingStyleNode({ 'INDENT' }, {
            ui.EmptyLine(),
            loading_view,
            table_view,
        }),
    }
end
