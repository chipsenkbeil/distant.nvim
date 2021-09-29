local distant = require('distant.lib.distant_nvim')

local function install_packer_if_missing()
    local install_path = vim.fn.stdpath('data') .. '/site/pack/packer/start/packer.nvim'

    if vim.fn.empty(vim.fn.glob(install_path)) > 0 then
        print('Installing packer.nvim')

        vim.fn.system({
            'git',
            'clone',
            'https://github.com/wbthomason/packer.nvim',
            install_path
        })
        vim.cmd([[packadd packer.nvim]])
  end
end
