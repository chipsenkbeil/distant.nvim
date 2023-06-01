--- @meta
--- Types related to testing

--- @param label string
--- @param f fun()
function describe(label, f)
end

--- @param label string
--- @param f fun()
function it(label, f)
end

--- @param label string
--- @param f fun()
function pending(label, f)
end

--- @param f fun()
function before_each(f)
end

--- @param f fun()
function after_each(f)
end
