
" TODO: use conceal only in terminal version???
" TODO: use BufEnter/Leave to increase/decrease conceal contrast
"hi Conceal term=underline cterm=bold ctermfg=LightGray

setlocal nowrap
setlocal switchbuf=useopen

" Matchit support
if exists("loaded_matchit") && !exists("b:match_words")
  let b:match_ignorecase = 0

  let b:match_words = '^\w\+\:\d\+\: call :^\w\+\:\d\+\: ret  ' .
        \ ',^\w\+\:\d\+\: handle_call :^\w\+\:\d\+\: .handle_call '

  "            \ ',{:},\[:\],(:)'
endif


augroup ElixirSmartTraceFile
  au!
  au CursorMoved <buffer> call vimelixirtrace#erltrace#highlightMatch()
augroup END

setlocal foldexpr=vimelixirtrace#erltrace#foldLevel(v:lnum)
setlocal foldtext=vimelixirtrace#erltrace#foldText()
setlocal foldmethod=expr
setlocal foldcolumn=0


command! -buffer -bang ErlTraceJumpToDef call vimelixirtrace#erltrace#findFileName('.', '<bang>')
map <buffer> <Enter> :ErlTraceJumpToDef!<CR>
map <buffer> p :ErlTraceJumpToDef<CR>

command! -buffer -nargs=1 ErlTraceNavSame call vimelixirtrace#erltrace#navigateSameFunc('<args>')

map <silent> <buffer> ; :ErlTraceNavSame fw<CR>
map <silent> <buffer> . :ErlTraceNavSame back<CR>

command! -buffer -nargs=1 ErlTraceNavFunc call vimelixirtrace#erltrace#navigateFunc('<args>')

map <silent> <buffer> ( :ErlTraceNavFunc back<CR>
map <silent> <buffer> ) :ErlTraceNavFunc fw<CR>

command! -buffer -nargs=1 ErlTraceNavSkip call vimelixirtrace#erltrace#navigateSkipFunc('<args>')

map <silent> <buffer> { :ErlTraceNavSkip back<CR>
map <silent> <buffer> } :ErlTraceNavSkip fw<CR>

" allow fold open/close even when 1 line above it on call/return definition
map <silent> <buffer> <F3> :call vimelixirtrace#erltrace#toggleFold()<CR>

