if !has('nvim-0.5')
  echoerr "distant.nvim requires at least nvim-0.5. Please update or uninstall"
  finish
end

if exists('g:loaded_distant')
  finish
endif
let g:loaded_distant = 1

" Ensure our autocmds are initialized
lua require('distant.internal.autocmd').initialize()

" Define our specialized commands that wrap the lua calls
command! -nargs=* DistantOpen lua require('distant.command').open(<f-args>)
command! -nargs=* DistantLaunch lua require('distant.command').launch(<f-args>)
command! -nargs=* DistantMetadata lua require('distant.command').metadata(<f-args>)
command! -nargs=0 DistantSessionInfo lua require('distant.command').session_info()
command! -nargs=0 DistantSystemInfo lua require('distant.command').system_info()

" Define our purely-functional commands that wrap the lua calls
command! -nargs=* DistantCopy lua require('distant.command').copy(<f-args>)
command! -nargs=* DistantMkdir lua require('distant.command').mkdir(<f-args>)
command! -nargs=* DistantRemove lua require('distant.command').remove(<f-args>)
command! -nargs=* DistantRename lua require('distant.command').rename(<f-args>)
command! -nargs=* DistantRun lua require('distant.command').run(<f-args>)
