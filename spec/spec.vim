set rtp+=.
set rtp+=vendor/plenary.nvim/

runtime! plugin/plenary.vim
runtime! plugin/distant.vim

lua require('plenary.busted')
