local Cmd = require('distant.client.cmd')

--- @param client Client
--- @return ClientTerm
return function(client)
    local term = {
        __state = {}
    }

    --- @overload fun():number
    --- @type fun(opts:{cmd?:string|string[]}):number
    term.spawn = function(opts)
        local c = opts.cmd
        if vim.tbl_islist(c) then
            c = table.concat(c, ' ')
        end
        if (vim.tbl_islist(c) and vim.tbl_isempty(c)) or (type(c) == 'string' and vim.trim(c) == '') then
            c = nil
        end

        --- @type string[]
        local cmd = client:build_cmd(
            Cmd.shell(c):set_from_tbl(vim.tbl_deep_extend('force', opts, {

            })),
            { list = true }
        )

        return vim.fn.termopen(cmd)
    end

    return term
end
