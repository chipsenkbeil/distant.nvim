local plugin = require('distant')

describe('distant.buffer.name.prefix', function()
    describe('format=modern', function()
        -- TODO: This will NOT work unless https://github.com/neovim/neovim/pull/23834 is merged;
        --       so, we have to disable this. If/once the above is merged, then this test would
        --       be feature-gated to that neovim release.
        pending('should use buffer name if none provided and no scheme provided', function()
            local bufnr = vim.api.nvim_create_buf(true, false)
            assert(bufnr ~= 0, 'Failed to create buffer')

            vim.api.nvim_buf_set_name(bufnr, 'distant-modern+1234://hello.txt')

            local prefix = plugin.buf(bufnr).name.prefix({ format = 'modern' })
            assert.are.equal(prefix, 'distant+1234')
        end)

        it('should use name if provided', function()
            local prefix = plugin.buf.name.prefix({
                format = 'modern',
                name = 'distant-modern+5678://hello.txt',
            })
            assert.are.equal(prefix, 'distant-modern+5678')
        end)

        it('should build and parse prefix from scheme if provided', function()
            local prefix = plugin.buf.name.prefix({
                format = 'modern',
                scheme = 'distant-modern',
            })
            assert.are.equal(prefix, 'distant-modern')
        end)

        it('should build and parse prefix from scheme & connection if provided', function()
            local prefix = plugin.buf.name.prefix({
                format = 'modern',
                scheme = 'distant-modern',
                connection = 9999,
            })
            assert.are.equal(prefix, 'distant-modern+9999')
        end)
    end)

    describe('format=legacy', function()
        it('should use buffer name if none provided and no scheme provided', function()
            local bufnr = vim.api.nvim_create_buf(true, false)
            assert(bufnr ~= 0, 'Failed to create buffer')

            vim.api.nvim_buf_set_name(bufnr, 'distant-legacy://1234://hello.txt')

            local prefix = plugin.buf(bufnr).name.prefix({ format = 'legacy' })
            assert.are.equal(prefix, 'distant-legacy://1234')
        end)

        it('should use name if provided', function()
            local prefix = plugin.buf.name.prefix({
                format = 'legacy',
                name = 'distant-legacy://5678://hello.txt',
            })
            assert.are.equal(prefix, 'distant-legacy://5678')
        end)

        it('should build and parse prefix from scheme if provided', function()
            local prefix = plugin.buf.name.prefix({
                format = 'legacy',
                scheme = 'distant-legacy',
            })
            assert.are.equal(prefix, 'distant-legacy')
        end)

        it('should build and parse prefix from scheme & connection if provided', function()
            local prefix = plugin.buf.name.prefix({
                format = 'legacy',
                scheme = 'distant-legacy',
                connection = 9999,
            })
            assert.are.equal(prefix, 'distant-legacy://9999')
        end)
    end)
end)
