local p  = require('distant.ui.palette')
local ui = require('distant-core.ui')

--- @param state distant.plugin.ui.windows.main.State
--- @return distant.core.ui.INode
return function(state)
    local system_info = state.info.system_info

    -- If system information isn't available, report as such
    local content

    -- Build a table of our system information
    if system_info then
        local rows = {}
        table.insert(rows, { key = 'Name', value = 'Value', header = true })
        table.insert(rows, { key = 'Family', value = system_info.family })
        table.insert(rows, { key = 'Operating System', value = system_info.os })
        table.insert(rows, { key = 'Arch', value = system_info.arch })
        table.insert(rows, { key = 'Current Directory', value = system_info.current_dir })
        table.insert(rows, { key = 'Main Separator', value = system_info.main_separator })
        table.insert(rows, { key = 'Username', value = system_info.username })
        table.insert(rows, { key = 'Shell', value = system_info.shell })

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

        content = ui.Table(vim.tbl_map(row_to_span, rows))
    end

    -- If content not available, report as such
    if not content then
        content = ui.Text {
            'System information is not available yet.',
            'Please establish a connection with a server first.',
        }
    end

    return ui.Node {
        ui.EmptyLine(),
        content,
        ui.EmptyLine(),
    }
end
