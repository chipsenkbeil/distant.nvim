if !has('nvim-0.8')
  echoerr "distant.nvim requires at least nvim-0.8. Please update or uninstall"
  finish
end

if exists('g:loaded_distant')
  finish
endif
let g:loaded_distant = 1

" Ensure our plugin is initialized and ready to go
" lua require('distant'):initialize()
