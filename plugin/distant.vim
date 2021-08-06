if !has('nvim-0.5')
  echoerr "distant.nvim requires at least nvim-0.5. Please update or uninstall"
  finish
end

if exists('g:loaded_distant')
  finish
endif
let g:loaded_distant = 1

" Define our specialized commands that wrap the lua calls
command! -nargs=* DistantOpen lua require('distant').action.open(<f-args>)
command! -nargs=* DistantLaunch lua require('distant').action.launch(<f-args>)
command! -nargs=* DistantMetadata lua require('distant').action.metadata(<f-args>)
command! -nargs=0 DistantSessionInfo lua require('distant').action.session_info()
command! -nargs=0 DistantSystemInfo lua require('distant').action.system_info()

" TODO: Remove me when done
command! -nargs=0 DistantTest lua require('distant.internal.lsp').test()

" Define our purely-functional commands that wrap the lua calls
command! -nargs=* DistantCopy lua require('distant').fn.copy(<f-args>)
command! -nargs=* DistantMkdir lua require('distant').fn.mkdir(<f-args>)
command! -nargs=* DistantRemove lua require('distant').fn.remove(<f-args>)
command! -nargs=* DistantRename lua require('distant').fn.rename(<f-args>)
command! -nargs=* DistantRun lua require('distant').fn.run(<f-args>)
