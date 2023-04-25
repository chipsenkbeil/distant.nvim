if !has('nvim-0.7')
  echoerr "distant.nvim requires at least nvim-0.7. Please update or uninstall"
  finish
end

if exists('g:loaded_distant')
  finish
endif
let g:loaded_distant = 1

" Ensure our autocmds are initialized
lua require('distant.autocmd').initialize()

" Define our specialized commands that wrap the lua calls
command! -nargs=* DistantOpen
      \ lua require('distant.command').open(vim.fn.expand('<args>'))
command! -nargs=* DistantLaunch
      \ lua require('distant.command').launch(vim.fn.expand('<args>'))
command! -nargs=* DistantConnect
      \ lua require('distant.command').connect(vim.fn.expand('<args>'))
command! -nargs=* DistantMetadata
      \ lua require('distant.command').metadata(vim.fn.expand('<args>'))
command! -nargs=* DistantInstall
      \ lua require('distant.command').install(vim.fn.expand('<args>'))
command! -nargs=* DistantShell
      \ lua require('distant.command').shell(vim.fn.expand('<args>'))
command! -nargs=0 DistantSessionInfo
      \ lua require('distant.command').session_info()
command! -nargs=0 DistantSystemInfo
      \ lua require('distant.command').system_info()
command! -nargs=0 DistantClientVersion
      \ lua require('distant.command').client_version()

" Define our purely-functional commands that wrap the lua calls
command! -nargs=* DistantCancelSearch
      \ lua require('distant.command').cancel_search(vim.fn.expand('<args>'))
command! -nargs=* DistantCopy
      \ lua require('distant.command').copy(vim.fn.expand('<args>'))
command! -nargs=* DistantMkdir
      \ lua require('distant.command').mkdir(vim.fn.expand('<args>'))
command! -nargs=* DistantRemove
      \ lua require('distant.command').remove(vim.fn.expand('<args>'))
command! -nargs=* DistantRename
      \ lua require('distant.command').rename(vim.fn.expand('<args>'))
command! -nargs=* DistantRun
      \ lua require('distant.command').run(vim.fn.expand('<args>'))
command! -nargs=* DistantSearch
      \ lua require('distant.command').search(vim.fn.expand('<args>'))
