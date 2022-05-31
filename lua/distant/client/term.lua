local Cmd = require('distant.client.cmd')

--- @param client Client
--- @return ClientTerm
return function(client)
    local term = {
        __state = {}
    }

    --- @overload fun():number
    --- @type fun(opts:{cmd?:string|string[]}, buf?:number, win?:number):number
    term.spawn = function(opts)
        local c = opts.cmd
        local is_table = type(c) == 'table'
        local is_string = type(c) == 'string'
        if (is_table and vim.tbl_isempty(c)) or (is_string and vim.trim(c) == '') then
            c = nil
        elseif is_table then
            c = table.concat(c, ' ')
        end

        --- @type string[]
        local cmd = client:build_cmd(
            Cmd.shell(c):set_from_tbl(vim.tbl_deep_extend('force', opts, {
                format = 'shell',
                session = 'pipe',
            })),
            { list = true }
        )

        -- Get or create the buffer we will be using with this terminal,
        -- ensure it is no longer modifiable, switch to it, and then
        -- spawn the remote shell
        local buf = opts.buf
        if buf == nil or buf == -1 then
            buf = vim.api.nvim_create_buf(true, false)
            assert(buf ~= 0, 'Failed to create buffer for remote shell')
        end
        vim.api.nvim_buf_set_option(buf, 'modifiable', false)
        vim.api.nvim_win_set_buf(opts.win or 0, buf)

        local job_id = vim.fn.termopen(cmd)

        if job_id == 0 then
            error('Invalid arguments: ' .. table.concat(cmd or {}, ' '))
        elseif job_id == -1 then
            local cmd_prog = c and vim.split(c, ' ', true)[1]
            if cmd_prog then
                error(cmd_prog .. ' is not executable')
            else
                error('Default shell is not executable')
            end
        end

        --- @type ClientDetails
        local details = assert(client:details(), 'No client details available')

        --- @type TcpSession
        local session = assert(details.tcp, 'No client session available')

        local session_str = string.format(
            'DISTANT CONNECT %s %s %s',
            session.host,
            session.port,
            session.key
        )

        -- Send our session prompt to start the shell connection
        -- with newline (empty string) to flush
        vim.fn.chansend(job_id, { session_str, '' })

        -- Clear the session line submitted so it isn't shown
        -- NOTE: For this to work, need to delay by N milliseconds,
        --       where 1ms seems to not work reliably
        vim.defer_fn(function()
            vim.api.nvim_buf_set_option(buf, 'modifiable', true)
            vim.api.nvim_buf_set_lines(buf, 0, 1, true, {})
            vim.api.nvim_buf_set_option(buf, 'modifiable', false)
        end, 10)

        return job_id
    end

    return term
end
