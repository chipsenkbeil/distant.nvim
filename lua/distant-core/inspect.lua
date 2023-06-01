--- @generic T
--- @param value T
--- @return T
return function(value)
    print(vim.inspect(value))
    return value
end
