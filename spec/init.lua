local cwd = vim.fn.getcwd()
local plenary_path = cwd .. '/vendor/plenary.nvim'

-- If plenary.nvim does not exist, clone it so we can use it for testing
if vim.fn.isdirectory(plenary_path) == 0 then
    print('Downloading plenary into: ', plenary_path)
    vim.fn.system {
        'git',
        'clone',
        '--depth=1',
        'https://github.com/nvim-lua/plenary.nvim',
        plenary_path,
    }
end

vim.opt.rtp:prepend(plenary_path)
vim.opt.rtp:prepend(cwd)

vim.cmd('runtime! plugin/plenary.vim')
vim.cmd('runtime! plugin/distant.vim')
