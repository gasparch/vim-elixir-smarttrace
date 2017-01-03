au BufRead,BufNewFile *.erltrace call s:setf('erltrace')

"au FileType elixir,eelixir setl sw=2 sts=2 et iskeyword+=!,?

function! s:setf(filetype) abort
  let &filetype = a:filetype
endfunction
