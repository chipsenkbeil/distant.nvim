local BaseCmd = require('distant.cli.cmd.base')

--- @class ProcSpawnCmd: BaseCmd
--- @field __cmd string
local ProcSpawnCmd = BaseCmd:new('proc-spawn', {
    allowed = {
        'config',
        'current-dir',
        'environment',
        'log-file',
        'log-level',
        'pty',
    }
})

--- Creates new shell cmd
--- @param prog? string #optional prog to run instead of $TERM
--- @return ProcSpawnCmd
function ProcSpawnCmd:new(prog)
    self.__internal = {}
    self.__prog = prog
    return self
end

--- Returns cmd as a list
--- @return string[]
function ProcSpawnCmd:as_list()
    local lst = BaseCmd.as_list(self)
    if self.__prog then
        table.insert(lst, '--')
        table.insert(lst, self.__prog)
    end
    return lst
end

--- Sets `--config <path>`
--- @param path string
--- @return ProcSpawnCmd
function ProcSpawnCmd:set_config(path)
    vim.validate({ path = { path, 'string' } })
    return self:set('config', path)
end

--- Sets `--current-dir <dir>`
--- @param dir string
--- @return ProcSpawnCmd
function ProcSpawnCmd:set_current_dir(dir)
    vim.validate({ dir = { dir, 'string' } })
    return self:set('current-dir', dir)
end

--- Sets `--environment <id>`
--- @param environment table<string, string>
--- @return ProcSpawnCmd
function ProcSpawnCmd:set_environment(environment)
    vim.validate({ environment = { environment, 'table' } })
    local s = ''
    for key, value in pairs(environment) do
        s = s .. key .. '="' .. value .. '='
    end

    return self:set('environment', s)
end

--- Sets `--log-file <value>`
--- @param value string
--- @return ProcSpawnCmd
function ProcSpawnCmd:set_log_file(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('log-file', value)
end

--- Sets `--log-level <value>`
--- @param value 'off'|'error'|'warn'|'info'|'debug'|'trace'
--- @return ProcSpawnCmd
function ProcSpawnCmd:set_log_level(value)
    vim.validate({ value = { value, 'string' } })
    return self:set('log-level', value)
end

--- Sets `--pty`
--- @return ProcSpawnCmd
function ProcSpawnCmd:set_pty()
    return self:set('pty')
end

return ProcSpawnCmd
