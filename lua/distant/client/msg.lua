local REQUEST = {
    FILE_READ = {
        type = 'file_read',
        data = {
            path = 'string',
        },
    },

    FILE_READ_TEXT = {
        type = 'file_read_text',
        data = {
            path = 'string',
        },
    },

    FILE_WRITE = {
        type = 'file_write',
        data = {
            path = 'string',
            data = 'table',
        },
    },

    FILE_WRITE_TEXT = {
        type = 'file_write_text',
        data = {
            path = 'string',
            text = 'string',
        },
    },

    FILE_APPEND = {
        type = 'file_append',
        data = {
            path = 'string',
            data = 'table',
        },
    },

    FILE_APPEND_TEXT = {
        type = 'file_append_text',
        data = {
            path = 'string',
            text = 'string',
        },
    },

    DIR_READ = {
        type = 'dir_read',
        data = {
            path = 'string',
            depth = {type = 'number', optional = true},
            absolute = {type = 'boolean', optional = true},
            canonicalize = {type = 'boolean', optional = true},
            include_root = {type = 'boolean', optional = true},
        },
    },

    DIR_CREATE = {
        type = 'dir_create',
        data = {
            path = 'string',
            all = {type = 'boolean', optional = true},
        },
    },

    REMOVE = {
        type = 'remove',
        data = {
            force = {type = 'boolean', optional = true},
        },
    },

    COPY = {
        type = 'copy',
        data = {
            src = 'string',
            dst = 'string',
        },
    },

    RENAME = {
        type = 'rename',
        data = {
            src = 'string',
            dst = 'string',
        },
    },

    WATCH = {
        type = 'watch',
        data = {
            path = 'string',
            recursive = {type = 'boolean', optional = true},
            only = {type = 'table', optional = true},
            except = {type = 'table', optional = true},
        },
    },

    UNWATCH = {
        type = 'unwatch',
        data = {
            path = 'string',
        },
    },

    EXISTS = {
        type = 'exists',
        data = {
            path = 'string',
        },
    },

    METADATA = {
        type = 'metadata',
        data = {
            path = 'string',
            canonicalize = {type = 'boolean', optional = true},
            resolve_file_type = {type = 'boolean', optional = true},
        },
    },

    PROC_SPAWN = {
        type = 'proc_spawn',
        data = {
            cmd = 'string',
            args = {type = 'table', optional = true},
            persist = {type = 'boolean', optional = true},
            pty = {type = 'table', optional = true},
        },
    },

    PROC_KILL = {
        type = 'proc_kill',
        data = {
            id = 'number',
        },
    },

    PROC_STDIN = {
        type = 'proc_stdin',
        data = {
            id = 'number',
            data = 'table',
        },
    },

    PROC_RESIZE_PTY = {
        type = 'proc_resize_pty',
        data = {
            id = 'number',
            size = 'table',
        },
    },

    PROC_LIST = {
        type = 'proc_list',
        data = {},
    },

    SYSTEM_INFO = {
        type = 'system_info',
        data = {},
    },
}

local RESPONSE = {
    OK = {
        type = 'ok',
        data = {},
    },

    ERROR = {
        type = 'error',
        data = {
            kind = 'string',
            description = 'string',
        },
    },

    BLOB = {
        type = 'blob',
        data = {
            data = 'table',
        },
    },

    TEXT = {
        type = 'text',
        data = {
            data = 'string',
        },
    },

    DIR_ENTRIES = {
        type = 'dir_entries',
        data = {
            entries = 'table',
            errors = 'table',
        },
    },

    CHANGED = {
        type = 'changed',
        data = {
            kind = 'string',
            paths = 'table',
        },
    },

    EXISTS = {
        type = 'exists',
        data = {
            value = 'boolean',
        },
    },

    METADATA = {
        type = 'metadata',
        data = {
            canonicalized_path = {type = 'string', optional = true},
            file_type = 'string',
            len = 'number',
            readonly = 'boolean',
            accessed = {type = 'number', optional = true},
            created = {type = 'number', optional = true},
            modified = {type = 'number', optional = true},
            unix = {type = 'table', optional = true},
            windows = {type = 'table', optional = true},
        },
    },

    PROC_SPAWNED = {
        type = 'proc_spawned',
        data = {
            id = 'number',
        },
    },

    PROC_STDOUT = {
        type = 'proc_stdout',
        data = {
            id = 'number',
            data = 'table',
        },
    },

    PROC_STDERR = {
        type = 'proc_stderr',
        data = {
            id = 'number',
            data = 'table',
        },
    },

    PROC_DONE = {
        type = 'proc_done',
        data = {
            id = 'number',
            success = 'boolean',
            code = {type = 'number', optional = true},
        },
    },

    PROC_ENTRIES = {
        type = 'proc_entries',
        data = {
            entries = 'table',
        },
    },

    SYSTEM_INFO = {
        type = 'system_info',
        data = {
            family = 'string',
            os = 'string',
            arch = 'string',
            current_dir = 'string',
            main_separator = 'string',
        },
    },
}

local function tbl_validate(tbl, info)
    local opts = {
        type = {tbl.type, 'string'},
    }

    for key, value in pairs(info.data) do
        local vtype = value
        local optional = false
        if type(vtype) == 'table' then
            vtype = value.type
            optional = value.optional
        end

        opts[key] = {tbl[key], vtype, optional}
    end

    -- Validate input types
    vim.validate(opts)

    -- Validate the table msg type is appropriate
    if tbl.type ~= info.type then
        error('[INVALID MSG] Expected ' .. info.type .. ' but got ' .. tbl.type, 2)
    end

    return tbl
end

--- Converts a JSON string into the msg type (validates against info)
---
--- @param value string|table The value to convert to a Lua table (parses JSON string)
--- @param info {type: string, data: table} The information to use to validate
--- @return table #The JSON string as a table
local function convert_from_json_and_validate(value, info)
    local tbl = value
    if type(tbl) == 'string' then
        tbl = vim.fn.json_decode(tbl)
    end

    if info ~= nil then
        tbl = tbl_validate(tbl, info)
    end

    return tbl
end

--- Converts a msg into a JSON string (validates against info)
---
--- @param tbl table The lua table to convert into a string
--- @param info {type: string, data: table} The information to use to validate
--- @return string #The table as a JSON string
local function validate_and_convert_to_json(tbl, info)
    return vim.fn.json_encode(tbl_validate(tbl, info))
end

local msg = {}

--- Parses a response JSON string into a table
---
--- @param s string The JSON string to parse
--- @return {tenant:string, id:number, origin_id:number, payload:{}}
function msg.parse_response(s)
    local tbl = s
    if type(tbl) == 'string' then
        tbl = vim.fn.json_decode(tbl)
    end

    vim.validate({
        tenant={tbl['tenant'], 'string'},
        id={tbl['id'], 'number'},
        origin_id={tbl['origin_id'], 'number'},
        payload={tbl['payload'], 'table'},
    })

    return tbl
end

-- Add specialty methods for each of the request types
-- 1. Converting from JSON and then validating
-- 2. Validating and converting into JSON
for key, info in pairs(REQUEST) do
    msg.req[key] = {
        from_json = function(value) convert_from_json_and_validate(value, info) end,
        to_json = function(tbl) validate_and_convert_to_json(tbl, info) end,
    }
end
for key, info in pairs(RESPONSE) do
    msg.res[key] = {
        from_json = function(value) convert_from_json_and_validate(value, info) end,
        to_json = function(tbl) validate_and_convert_to_json(tbl, info) end,
    }
end

return msg
