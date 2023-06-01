--- @class spec.e2e.Assert
--- @field same fun(lines:string|string[])

--- Constructs a new assert object.
--- @param opts {get_lines:fun():string[]}
--- @return spec.e2e.Assert
return function(opts)
    --- @type spec.e2e.Assert
    local instance = {}

    --- Asserts that the provided lines match this object's content.
    --- @param lines string|string[]
    function instance.same(lines)
        if type(lines) == 'string' then
            lines = vim.split(lines, '\n', { plain = true })
        end

        -- same(expected, actual)
        assert.are.same(lines, opts.get_lines())
    end

    return instance
end
