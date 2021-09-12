local editor = require('distant.editor')
local Driver = require('spec.e2e.driver')

-- Remove indentation
local function d(level, text)
    local out = {}
    local start = (level * 4) + 1
    for _, line in ipairs(vim.split(text, '\n', true)) do
        table.insert(out, string.sub(line, start))
    end
    return table.concat(out, '\n')
end

-- Creates a rust project using the provided remote directory
local function make_rust_project(root)
    assert(root.file('Cargo.toml').write(d(2, [[
        [package]
        name = "testapp"
        version = "0.1.0"
        edition = "2018"

        [dependencies]
    ]])), 'Failed to create Cargo.toml')

    assert(root.dir('src').make(), 'Failed to make src/ dir')

    assert(root.dir('src').file('main.rs').write(d(2, [[
        mod other;

        fn main() {
            other::say_hello();
        }
    ]])), 'Failed to create src/main.rs')

    assert(root.dir('src').file('other.rs').write(d(2, [[
        pub fn say_hello() {
            println!("Hello, world!");
        }
    ]])), 'Failed to create src/other.rs')
end

local function try_buf_request(bufnr, method)
    local function make_request_sync()
        return vim.lsp.buf_request_sync(
            bufnr,
            method,
            vim.lsp.util.make_position_params(),
            90 * 1000
        )
    end

    local value
    vim.wait(100 * 1000, function()
        local ok, v = pcall(make_request_sync)
        value = v
        return ok
    end)
    return value
end

describe('editor.lsp', function()
    local driver, root

    before_each(function()
        driver = Driver:setup({lazy = true})
        root = driver:new_dir_fixture()
        driver:initialize({
            settings = {
                ['*'] = {
                    client = {
                        log_file = '/tmp/test.distant.client.log',
                        verbose = 3,
                    },
                    lsp = {
                        ['rust'] = {
                            cmd = { 'rls' },
                            filetypes = { 'rust' },
                            root_dir = root.path(),
                            opts = { log_file = '/tmp/test.distant.rust.log', verbose = 3 },
                        }
                    }
                }
            }
        })
    end)

    after_each(function()
        -- Will remove all fixtures
        driver:teardown()
    end)

    it('should support navigating to other files that are remote', function()
        make_rust_project(root)
        driver.exec('sh', {'-c', '"cd ' .. root.path() .. ' && $HOME/.cargo/bin/cargo build"'})

        -- Open main.rs, which should start the LSP server
        local main_rs = root.dir('src').file('main.rs')
        local buf = driver.buffer(editor.open(main_rs.path()))

        -- Wait for the language server to be ready
        assert(
            vim.wait(1000 * 5, function() return vim.lsp.buf.server_ready() end),
            'Language server not ready'
        )

        -- Jump to other::say_hello() and have cursor on say_hello
        local ln, col = driver.window().move_cursor_to('say_hello')
        assert.are.equal(4, ln)
        assert.are.equal(11, col)

        -- Perform request in blocking fashion to make sure that we're ready
        -- NOTE: This does not perform a jump or anything else
        local res = try_buf_request(buf.id(), 'textDocument/definition')
        assert(res, 'Failed to get definition')

        -- Now perform the actual engagement
        vim.lsp.buf.definition()

        -- Verify that we eventually switch to a new buffer
        -- NOTE: Wait up to a minute for this to occur
        local success = vim.wait(1000 * 10, function()
            local id = vim.api.nvim_get_current_buf()
            return buf.id() ~= id
        end, 500)
        assert(success, 'LSP never switched to new buffer')

        -- Ensure that we properly populated the new buffer
        buf = driver.buffer()
        assert.are.equal('rust', buf.filetype())
        assert.are.equal('acwrite', buf.buftype())
        assert.are.equal('distant://' .. root.dir('src').file('other.rs').path(), buf.name())
        assert.are.equal(root.dir('src').file('other.rs').path(), buf.remote_path())
        buf.assert.same(d(3, [[
            pub fn say_hello() {
                println!("Hello, world!");
            }
        ]]))
    end)
end)
