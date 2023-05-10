local fn = require('distant.fn')
local Ui = require('distant-core.ui')
local p = require('distant.ui.palette')

--- @param state distant.ui.State
--- @return distant.core.ui.INode
return function(state)
    if not fn.is_ready() then
        return Ui.Node {}
    end

    local system_info = state.info.system_info

    return Ui.CascadingStyleNode({ 'INDENT' }, {
        Ui.When(state.view.current == 'Connections', function()
            return Ui.Node {}
        end),
        Ui.When(state.view.current == 'System Info' and system_info ~= nil, function()
            assert(system_info)

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

            return Ui.Node {
                Ui.EmptyLine(),
                Ui.Table(vim.tbl_map(row_to_span, rows)),
                Ui.EmptyLine(),
            }
        end),
        Ui.When(state.view.current == 'System Info' and system_info == nil, function()
            return Ui.Node {
                Ui.EmptyLine(),
                Ui.Text { 'Loading system information...' },
                Ui.EmptyLine(),
            }
        end),
    })
end
