local config = require('spec.e2e.config')
local Driver = require('spec.e2e.driver')
local plugin = require('distant')

-- Remove indentation
local function d(level, text)
    local out = {}
    local start = (level * 4) + 1
    for _, line in ipairs(vim.split(text, '\n', { plain = true })) do
        table.insert(out, string.sub(line, start))
    end
    return table.concat(out, '\n')
end

--- Creates a lua project using the provided remote directory
--- @param root spec.e2e.RemoteDir
--- @return spec.e2e.RemoteDir lua_dir
local function make_lua_project(root)
    local lua_dir = root:dir('lua')
    assert(lua_dir:make(), 'Failed to create lua/')

    assert(lua_dir:file('init.lua'):write(d(2, [[
        local other = require('other')
        other.say('Hello, world!')
    ]])), 'Failed to create lua/init.lua')

    assert(lua_dir:file('other.lua'):write(d(2, [[
        local M = {}

        function M.say(msg)
            print(msg)
        end

        return M
    ]])), 'Failed to create lua/other.rs')

    return lua_dir
end

--- @param bufnr number
--- @param method string
--- @param params? table
local function try_buf_request(bufnr, method, params)
    params = params or {}
    local function make_request_sync()
        return vim.lsp.buf_request_sync(
            bufnr,
            method,
            vim.tbl_deep_extend(
                'keep',
                --- @diagnostic disable-next-line:missing-parameter
                vim.lsp.util.make_position_params(),
                params
            ),
            --- @diagnostic disable-next-line:param-type-mismatch
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

describe('distant.editor.lsp', function()
    --- @type spec.e2e.Driver, spec.e2e.RemoteDir
    local driver, root

    before_each(function()
        driver = Driver:setup({
            label = 'distant.editor.lsp',
            lazy = true,

            -- Disable watching buffer content changes for our tests
            settings = {
                buffer = {
                    watch = {
                        enabled = false
                    }
                }
            },
        })
        root = driver:new_dir_fixture()

        local root_dir = { root:path() }
        local root_canonicalized_path = root:canonicalized_path({
            ignore_errors = true
        })
        if root_canonicalized_path then
            table.insert(root_dir, root_canonicalized_path)
        end

        driver:initialize({
            -- Provide custom settings to define our LSP for the server
            settings = {
                servers = {
                    ['*'] = {
                        lsp = {
                            ['lua'] = {
                                cmd = { config.lsp_cmd },
                                filetypes = { 'lua' },
                                root_dir = root_dir,
                            }
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
        driver:debug_print(string.format('LSP will log to %s', vim.lsp.get_log_path()))
        vim.lsp.set_log_level('TRACE')

        driver:debug_print('Making lua project')
        local lua_dir = make_lua_project(root)

        -- Open main.rs, which should start the LSP server
        local init_lua = lua_dir:file('init.lua')
        driver:debug_print('Opening ' .. init_lua:path())
        local buffer = driver:buffer(plugin.editor.open(init_lua:path()))
        driver:debug_print('Opened into buffer ' .. buffer:id())
        assert(buffer:is_focused(), 'init.lua buffer not in focus')

        -- Wait for the language server to be ready
        driver:debug_print('Waiting on language server')
        local time = 1000 * 5
        assert(
            vim.wait(time, function() return vim.lsp.buf.server_ready() end),
            string.format('Language server not ready after %0.2fs', time / 1000.0)
        )

        -- Jump to other.say() and have cursor on say
        driver:debug_print('Jumping to say')
        local ln, col = driver:window():move_cursor_to('say')
        assert.are.equal(2, ln)
        assert.are.equal(6, col)

        -- Perform request in blocking fashion to make sure that we're ready
        -- NOTE: This does not perform a jump or anything else
        driver:debug_print('Waiting to be ready')
        local res = try_buf_request(buffer:id(), 'textDocument/definition')
        assert(res, 'Failed to get definition')

        -- Now perform the actual engagement
        driver:debug_print('Performing definition request')
        vim.lsp.buf.definition()

        -- Verify that we eventually switch to a new buffer
        -- NOTE: Wait up to a minute for this to occur
        driver:debug_print('Waiting to jump to definition')
        local success = vim.wait(1000 * 10, function()
            local id = vim.api.nvim_get_current_buf()
            return buffer:id() ~= id
        end, 500)
        assert(success, 'LSP never switched to new buffer')

        -- Ensure that we properly populated the new buffer
        driver:debug_print('Checking buffer is properly populated')
        buffer = driver:buffer()
        assert.are.equal('lua', buffer:filetype())
        assert.are.equal('acwrite', buffer:buftype())

        if plugin.buf.name.default_format() == 'modern' then
            assert.are.equal(
                'distant+' .. driver:client_id() .. '://' .. lua_dir:file('other.lua'):canonicalized_path(),
                buffer:name()
            )
        else
            assert.are.equal(
                'distant://' .. driver:client_id() .. '://' .. lua_dir:file('other.lua'):canonicalized_path(),
                buffer:name()
            )
        end
        assert.are.equal(lua_dir:file('other.lua'):canonicalized_path(), buffer:remote_path())
        buffer.assert.same(d(3, [[
            local M = {}

            function M.say(msg)
                print(msg)
            end

            return M
        ]]))
    end)

    pending('should support renaming symbols in remote files', function()
        make_lua_project(root)
        driver:exec('sh', { '-c', '"cd ' .. root:path() .. ' && $HOME/.cargo/bin/cargo build"' })

        -- Open main.rs, which should start the LSP server
        local main_rs = root:dir('src'):file('main.rs')
        local buf = driver:buffer(plugin.editor.open(main_rs:path()))

        -- Wait for the language server to be ready
        assert(
            vim.wait(1000 * 5, function() return vim.lsp.buf.server_ready() end),
            'Language server not ready'
        )

        -- Jump to other::say_hello() and have cursor on say_hello
        local ln, col = driver:window():move_cursor_to('say_hello')
        assert.are.equal(4, ln)
        assert.are.equal(11, col)

        -- Perform request in blocking fashion to make sure that we're ready
        -- NOTE: This does not perform a jump or anything else
        local res = try_buf_request(buf:id(), 'textDocument/definition')
        assert(res, 'Failed to get definition')

        -- Now perform the rename in blocking fashion
        --- @diagnostic disable-next-line:missing-parameter
        local params = vim.lsp.util.make_position_params()
        params.newName = 'print_hello'

        --- @diagnostic disable-next-line:param-type-mismatch
        local _, err = vim.lsp.buf_request_sync(buf:id(), 'textDocument/rename', params, 1000 * 10)
        assert(not err, tostring(err))

        -- Verify that we did rename in the buffer
        buf.assert.same(d(3, [[
            mod other;

            fn main() {
                other::print_hello();
            }
        ]]))

        -- Next, neovim's rename actually opens all of the files in other buffers and makes the changes,
        -- so we want to write all of them to verify that the contents change
        vim.cmd([[wall]])

        -- Verify that the underlying files changed
        root:dir('src'):file('main.rs').assert.same(d(3, [[
            mod other;

            fn main() {
                other::print_hello();
            }
        ]]))
        root:dir('src'):file('other.rs').assert.same(d(3, [[
            pub fn print_hello() {
                println!("Hello, world!");
            }
        ]]))
    end)
end)
