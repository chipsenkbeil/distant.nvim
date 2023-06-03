local plugin = require('distant')
local Driver = require('spec.e2e.driver')

describe('distant.api.metadata', function()
    --- @type spec.e2e.Driver, spec.e2e.RemoteDir
    local driver, root

    before_each(function()
        driver = Driver:setup({ label = 'distant.api.metadata' })
        root = driver:new_dir_fixture()
    end)

    after_each(function()
        driver:teardown()
    end)

    describe('synchronous', function()
        it('should return metadata for files', function()
            local file = root:file()
            assert(file:touch(), 'Failed to create file: ' .. file:path())

            local err, res = plugin.api.metadata({ path = file:path() })
            assert(not err, tostring(err))
            assert(res)

            assert.are.equal(res.file_type, 'file')
            assert.is.falsy(res.canonicalized_path)
        end)

        it('should return metadata for directories', function()
            local dir = root:dir()
            assert(dir:make(), 'Failed to create directory: ' .. dir:path())

            local err, res = plugin.api.metadata({ path = dir:path() })
            assert(not err, tostring(err))
            assert(res)

            assert.are.equal(res.file_type, 'dir')
            assert.is.falsy(res.canonicalized_path)
        end)

        it('should support metadata for symlinks', function()
            local file = root:file()
            assert(file:touch(), 'Failed to create file: ' .. file:path())

            local symlink = root:symlink()
            assert(symlink:make(file:path()), 'Failed to create symlink: ' .. symlink:path())

            local err, res = plugin.api.metadata({ path = symlink:path() })
            assert(not err, tostring(err))
            assert(res)

            assert.are.equal(res.file_type, 'symlink')
        end)

        it('should support resolving symlinks to underlying type', function()
            local file = root:file()
            assert(file:touch(), 'Failed to create file: ' .. file:path())

            local symlink = root:symlink()
            assert(symlink:make(file:path()), 'Failed to create symlink: ' .. symlink:path())

            local err, res = plugin.api.metadata({ path = symlink:path(), resolve_file_type = true })
            assert(not err, tostring(err))
            assert(res)

            assert.are.equal(res.file_type, 'file')
        end)

        it('should support returning a canonicalized path', function()
            local file = root:file()
            assert(file:touch(), 'Failed to create file: ' .. file:path())

            local symlink = root:symlink()
            assert(symlink:make(file:path()), 'Failed to create symlink: ' .. symlink:path())

            local err, res = plugin.api.metadata({ path = symlink:path(), canonicalize = true })
            assert(not err, tostring(err))
            assert(res)

            assert.are.equal(res.file_type, 'symlink')
            assert.are.equal(res.canonicalized_path, file:canonicalized_path())
        end)

        it('should fail if the path does not exist', function()
            local file = root:file()
            local err, res = plugin.api.metadata({ path = file:path() })
            assert.is.truthy(err)
            assert.is_nil(res)
        end)
    end)

    describe('asynchronous', function()
        it('should return metadata for files', function()
            local file = root:file()
            assert(file:touch(), 'Failed to create file: ' .. file:path())

            local capture = driver:new_capture()
            --- @diagnostic disable-next-line:param-type-mismatch
            plugin.api.metadata({ path = file:path() }, capture)

            local err, res = capture.wait()
            assert(not err, tostring(err))
            assert(res)

            assert.are.equal(res.file_type, 'file')
            assert.is.falsy(res.canonicalized_path)
        end)

        it('should return metadata for directories', function()
            local dir = root:dir()
            assert(dir:make(), 'Failed to create directory: ' .. dir:path())

            local capture = driver:new_capture()
            --- @diagnostic disable-next-line:param-type-mismatch
            plugin.api.metadata({ path = dir:path() }, capture)

            local err, res = capture.wait()
            assert(not err, tostring(err))
            assert(res)

            assert.are.equal(res.file_type, 'dir')
            assert.is.falsy(res.canonicalized_path)
        end)

        it('should support metadata for symlinks', function()
            local file = root:file()
            assert(file:touch(), 'Failed to create file: ' .. file:path())

            local symlink = root:symlink()
            assert(symlink:make(file:path()), 'Failed to create symlink: ' .. symlink:path())

            local capture = driver:new_capture()
            --- @diagnostic disable-next-line:param-type-mismatch
            plugin.api.metadata({ path = symlink:path() }, capture)

            local err, res = capture.wait()
            assert(not err, tostring(err))
            assert(res)

            assert.are.equal(res.file_type, 'symlink')
        end)

        it('should support resolving symlinks to underlying type', function()
            local file = root:file()
            assert(file:touch(), 'Failed to create file: ' .. file:path())

            local symlink = root:symlink()
            assert(symlink:make(file:path()), 'Failed to create symlink: ' .. symlink:path())

            local capture = driver:new_capture()
            --- @diagnostic disable-next-line:param-type-mismatch
            plugin.api.metadata({ path = symlink:path(), resolve_file_type = true }, capture)

            local err, res = capture.wait()
            assert(not err, tostring(err))
            assert(res)

            assert.are.equal(res.file_type, 'file')
        end)

        it('should support returning a canonicalized path', function()
            local file = root:file()
            assert(file:touch(), 'Failed to create file: ' .. file:path())

            local symlink = root:symlink()
            assert(symlink:make(file:path()), 'Failed to create symlink: ' .. symlink:path())

            local capture = driver:new_capture()
            --- @diagnostic disable-next-line:param-type-mismatch
            plugin.api.metadata({ path = symlink:path(), canonicalize = true }, capture)

            local err, res = capture.wait()
            assert(not err, tostring(err))
            assert(res)

            assert.are.equal(res.file_type, 'symlink')
            assert.are.equal(res.canonicalized_path, file:canonicalized_path())
        end)

        it('should fail if the path does not exist', function()
            local file = root:file()
            local capture = driver:new_capture()
            --- @diagnostic disable-next-line:param-type-mismatch
            plugin.api.metadata({ path = file:path() }, capture)

            local err, res = capture.wait()
            assert.is.truthy(err)
            assert.is_nil(res)
        end)
    end)
end)
