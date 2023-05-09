if !has('nvim-0.8')
  echoerr "distant.nvim requires at least nvim-0.8. Please update or uninstall"
  finish
end

if exists('g:loaded_distant')
  finish
endif
let g:loaded_distant = 1

" Ensure our autocmds are initialized
lua require('distant.autocmd').initialize()

" Ensure our commands are initialized
lua require('distant.commands').initialize()

" Ensure our user interface is initialized
lua require('distant.ui').initialize()
