"
" Vim-Elixir-SmartTrace allows tight integration of Erlang tracing and Elixir
" source browsing
"
" (items with 'x' are done)
" TODO:
"
"
" - running
"   - run selected piece of code with tracing enabled
"   - collect trace file
"
" - opening trace file
"   - convert existing trace file in human readable way
"       - call support
"       - return values support
"       - message send support
"       - message receive support
"   - decode GenServer calls in a nice way
"   - find function clause corresponding to supplied arguments
"     - put it into interpreted trace file
"   - find send function call???
"     - put it into interpreted trace file
"   - find receive function call???
"     - put it into interpreted trace file
"   - convert msg sender/receiver into ProcA/ProcB/etc notation
"       - possibly use module names if each sender/recv process initiated from
"         different module
"   - allow folding of calling arguments it too long (more than 1 line)
"
" - navigation
"   - jump to called/returning function from trace window
"   - go to next/prev function call
"   -
"

let s:BOOT_FINISHED = 0

function! vimelixirsmarttrace#boot() " {{{
  " TODO: move into if below?
  call vimelixirsmarttrace#setDefaults()

  if !s:BOOT_FINISHED
      call vimelixirsmarttrace#bootGlobal()
      let s:BOOT_FINISHED = 1
  endif

  " this happens in each buffer
  if g:vim_elixir_trace_selection | call vimelixirsmarttrace#setTraceCommand() | endif
endfunction " }}}

function! vimelixirsmarttrace#setDefaults() "{{{
  if !exists('g:vim_elixir_trace_shell')
      let g:vim_elixir_trace_shell = &shell
  endif
  call s:setGlobal('g:vim_elixir_trace_selection', 1)
endfunction "}}}

function! vimelixirsmarttrace#bootGlobal() " {{{
endfunction " }}}

function! vimelixirsmarttrace#setTraceCommand() " {{{
    "let mixDir = vimelixirsmarttrace#findMixDirectory()
    "command! -bang -buffer MixCompile call vimelixirsmarttrace#runMixCompileCommand('<bang>')
    command! -range TraceSelection call vimelixirsmarttrace#runTraceSelectionCommand('!', <line1>, <line2>)

    command! TraceTest call vimelixirsmarttrace#runTracedTest()
    "map <buffer> <Leader>xc :MixCompile<CR>
endfunction " }}}

function! vimelixirsmarttrace#runTraceSelectionCommand(arg, line1, line2) " {{{
    let text = join(getline(a:line1, a:line2), "\n")

    return s:runTrace(text, 'dev', '')
endfunction " }}}

function! vimelixirsmarttrace#runTracedTest() " {{{
    let mixDir = vimelixirsmarttrace#findMixDirectory()

    let fileName = expand('%:p')
    let fileName = substitute(fileName, mixDir . '/', '', '')

    let testSpec = escape(fileName, ' ') . ':' . line('.')

    let text = 'Mix.Task.run "test", ["'.testSpec.'"]'

    return s:runTrace(':ok', 'test', testSpec)
endfunction " }}}

function! s:runTrace(code, env, testSpec) "{{{
    let mixDir = vimelixirsmarttrace#findMixDirectory()

    let tempName = tempname() .".erltrace"
    let srcTempName = fnameescape(tempname() .".exs")

    let txt = vimelixirtrace#dump#dump(tempName, a:code, a:testSpec)
    call s:writeToFile(txt, srcTempName)

    " save options and locale env variables
    let old_cwd = getcwd()
    execute 'lcd ' . fnameescape(mixDir)

    let mixPrg = "env MIX_ENV='".a:env."' mix run " . fnameescape(srcTempName)

    call s:echoInfoText('starting trace run')

    let trace_output = s:system(mixPrg)

    execute 'lcd ' . fnameescape(old_cwd)

    " read output of this script into window and bind shortcuts to explore it
    " see zip.vim for Browse function
    "
    " /usr/share/vim/vim80/autoload/zip.vim
    "

    let trace_output = s:processTraceDump(trace_output)

    silent! new
    silent! setlocal buftype=nofile noswapfile nobuflisted ft=erltrace
    silent! put=trace_output
    silent! normal ggdd

endfunction "}}}

" Get the value of a Vim variable.  Allow local variables to override global ones.
function! s:rawVar(name, ...) abort " {{{
    return get(b:, a:name, get(g:, a:name, a:0 > 0 ? a:1 : ''))
endfunction " }}}

" Get the value of a syntastic variable.  Allow local variables to override global ones.
function! s:var(name, ...) abort " {{{
    return call('s:rawVar', ['vim_elixir_trace_' . a:name] + a:000)
endfunction " }}}

function s:system(command) abort "{{{
    let old_shell = &shell
    let old_lc_messages = $LC_MESSAGES
    let old_lc_all = $LC_ALL

    let &shell = s:var('shell')
    let $LC_MESSAGES = 'C'
    let $LC_ALL = ''

    "let cmd_start = reltime()
    let out = system(a:command)
    "let cmd_time = split(reltimestr(reltime(cmd_start)))[0]

    let $LC_ALL = old_lc_all
    let $LC_MESSAGES = old_lc_messages

    let &shell = old_shell

    return out
endfunction "}}}

function! s:writeToFile(message, file) "{{{
  silent! new
  silent! setlocal buftype=nofile bufhidden=hide noswapfile nobuflisted
  silent! put=a:message
  silent! normal ggdd
  silent! execute 'w ' a:file
  silent! q
endfunction "}}}

function! s:appendToFile(message, file) "{{{
  silent! new
  silent! setlocal buftype=nofile bufhidden=hide noswapfile nobuflisted
  silent! put=a:message
  silent! normal ggdd
  silent! execute 'w >>' a:file
  silent! q
endfunction "}}}

function! vimelixirsmarttrace#findMixDirectory() "{{{
    let fName = expand("%:p:h")

    while 1
        let mixFileName = fName . "/mix.exs"
        if file_readable(mixFileName)
            return fName
        endif

        let fNameNew = fnamemodify(fName, ":h")
        " after we reached top of heirarchy
        if fNameNew == fName
            return ''
        endif
        let fName = fNameNew
    endwhile
endfunction "}}}

function! s:echoWarning(text) "{{{
    echohl WarningMsg | echo a:text | echohl None
endfunction "}}}

function! s:echoNormal(text) "{{{
    echohl Normal | echo a:text | echohl None
endfunction "}}}

function! s:echoInfoText(text) "{{{
    echohl Question | echo a:text | echohl None
endfunction "}}}

function! s:echoDull(text) "{{{
    echohl Normal | echo a:text | echohl None
endfunction "}}}

function! s:setGlobal(name, default) " {{{
  if !exists(a:name)
    if type(a:name) == 0 || type(a:name) == 5
      exec "let " . a:name . " = " . a:default
    elseif type(a:name) == 1
      exec "let " . a:name . " = '" . escape(a:default, "\'") . "'"
    endif
  endif
endfunction " }}}

function! vimelixirsmarttrace#runTraceHighlight() "{{{
    " TODO: use conceal only in terminal version???
    " TODO: use BufEnter/Leave to increase/decrease conceal contrast
    "hi Conceal term=underline cterm=bold ctermfg=LightGray

    syntax match Comma "❟" conceal cchar=,
    if has("gui_running")
        syntax match EOFStart "«⋯"
        syntax match EOFEnd "⋯»"
        syntax match ReturnValue "⤶"
        syntax match MessageSend "→"
        syntax match MessageRecv "←"
        syntax match MessageDeadProcess "^\w\+→☠\w\+"
    else
        syntax match EOFStart "«⋯" conceal cchar=<
        syntax match EOFEnd "⋯»" conceal cchar=>
        syntax match ReturnValue "⤶" conceal cchar=<
        syntax match MessageSend "→" conceal cchar=>
        syntax match MessageRecv "←" conceal cchar=<
        syntax match MessageDeadProcess "^\w\+→☠\w\+"
    endif

    hi link MessageDeadProcess Error
    hi link EOFStart    Comment
    hi link EOFEnd      Comment
    hi link ReturnValue Comment
    hi link MessageSend Comment
    hi link MessageRecv Comment
    hi link Comma       Comment

    augroup ElixirSmartTraceFile
        au!
        au CursorMoved <buffer> call vimelixirsmarttrace#highlightMatch()
    augroup END
endfunction "}}}

let s:highlightMatch = 0
function! vimelixirsmarttrace#highlightMatch() "{{{
    let ln = getline('.')

    let matches = matchlist(ln, '^\([A-Z]\):\(\d\+\): \(\w\+\) ')

    if len(matches) == 0
        return
    endif

    if s:highlightMatch
        silent! call matchdelete(s:highlightMatch)
        let s:highlightMatch = 0
    endif

    let direction = 'nW'
    if matches[3] == 'ret'
        let direction .= 'b'
    endif

    let prefix = '^' . matches[1] . ':' . matches[2] . ': '

    let [matchLnNum, ignoreCol] = searchpairpos(prefix . 'call', '', prefix . 'ret', direction)

    if matchLnNum == 0
        return
    endif

    let currentNum = line('.')

    let s:highlightMatch = matchadd('MatchParen', '^\%(\%'. matchLnNum .'l\|\%'.currentNum.'l\)[A-Z]\+:\d\+: \w\+', 16, -1)
endfunction "}}}

function! s:processTraceDump(text) "{{{
    let lines = split(a:text, "\n")

    while len(lines) > 0 && lines[0] !~ '^======== trace start ========'
        call remove(lines, 0)
    endwhile

    if len(lines) > 0 && lines[0] =~ '^======== trace start ========'
        call remove(lines, 0)
    endif

    while len(lines) > 0 && lines[len(lines)-1] !~ '^======== trace stop ========'
        call remove(lines, -1)
    endwhile

    if len(lines) > 0 && lines[len(lines)-1] =~ '^======== trace stop ========'
        call remove(lines, -1)
    endif

    return join(lines, "\n")
endfunction "}}}

augroup ElixirSmartTrace " {{{
    au!
    au FileType erltrace call vimelixirsmarttrace#runTraceHighlight()
augroup END " }}}

" vim: set sw=4 sts=4 et fdm=marker:
"
