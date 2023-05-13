--- Creates part of a request, representing one portion of the payload.
--- @generic T
--- @param opts T
--- @return distant.core.api.batch.PartialRequest
local function make_partial_request(opts)
    --- @class distant.core.api.batch.PartialRequest
    --- @field err? distant.core.api.Error
    --- @field payload? table
    local instance = {}

    local __done = false

    --- @generic T
    --- @return T
    function instance.opts()
        return opts
    end

    --- Returns whether or not a response has been received.
    --- @return boolean
    function instance.is_done()
        return __done == true
    end

    --- @param opts {err?:distant.core.api.Error, payload?:table}
    function instance.complete(opts)
        if type(opts.err) == 'table' then
            instance.err = opts.err
        elseif opts.payload ~= nil then
            instance.payload = opts.payload
        else
            error('Partial request completed without error or payload!')
        end

        __done = true
    end

    return instance
end


--- @class distant.core.api.Batch
--- @field private api distant.core.Api
local M = {}

--- @param tbl distant.core.api.Batch
--- @param key string
--- @return fun(opts:table):distant.core.api.batch.PartialRequest
function M.__index(tbl, key)
    key = tostring(key)
    if type(tbl.api[key]) ~= 'function' then
        error('Batch call of api.' .. key .. ' does not exist')
    end

    --- Function that takes in the options and spits out a partial request.
    --- @param opts table
    --- @param ... any
    --- @return distant.core.api.batch.PartialRequest
    --- @diagnostic disable-next-line:redundant-parameter
    return function(opts, ...)
        if not vim.tbl_isempty({ ... }) then
            error('Batch call of api.' .. key .. ' can only accept single opts param')
        end

        return make_partial_request(opts)
    end
end

--- @param api distant.core.Api
--- @return distant.core.api.Batch
function M:new(api)
    local instance = {}
    setmetatable(instance, M)
    instance.api = api
    return instance
end

return M
