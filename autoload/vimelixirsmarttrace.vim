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

" support MixCompile
let s:traceTemplate = "#\n
            \ :dbg.stop_clear\n
            \ :dbg.start\n
            \ \n
            \ port_fun = :dbg.trace_port(:file, '%%FILE%%')\n
            \ :dbg.tracer(:port, port_fun)\n
            \ \n
            \ alias Mix.Tasks.Compile.Elixir, as: E\n
            \ import Mix.Compilers.Elixir, only: [read_manifest: 2, module: 1]\n
            \ \n
            \ # start tracing for all modules in project\n
            \ for manifest <- E.manifests(),\n
            \     module(module: mod_name) <- read_manifest(manifest, \"\"), \n
            \ do: \n
            \     :dbg.tpl mod_name, [{:'_', [], [{:return_trace}]}]\n
            \ \n
            \ :dbg.p(:new_processes, [:c, :m])\n
            \ \n
            \ # TODO: add waiting until CODE finishes execution and then only stop \n
            \ # the tracer \n
            \ spawn(fn() -> %%CODE%% end)\n
            \ \n
            \ :dbg.trace_port_control(node(), :flush)\n
            \ :dbg.stop\n
            \ Process.sleep 1500\n
            \ \n
            \ defmodule TraceReader do\n
            \   def read(x,state) do\n
            \     IO.inspect x, limit: 10000, pretty: true, width: 140\n
            \     state \n
            \   end\n
            \ end\n
            \ :dbg.trace_client(:file, '%%FILE%%', {&TraceReader.read/2, :zero_state}) \n
            \ Process.sleep 1500\n
            \ \n
            \"

function! vimelixirsmarttrace#setTraceCommand() " {{{
    "let mixDir = vimelixirsmarttrace#findMixDirectory()
    "command! -bang -buffer MixCompile call vimelixirsmarttrace#runMixCompileCommand('<bang>')
    command! -range TraceSelection call vimelixirsmarttrace#runTraceSelectionCommand('!', <line1>, <line2>)
    "map <buffer> <Leader>xc :MixCompile<CR>
endfunction " }}}

function! vimelixirsmarttrace#runTraceSelectionCommand(arg, line1, line2) " {{{
    let mixDir = vimelixirsmarttrace#findMixDirectory()

    let text = join(getline(a:line1, a:line2), "\n")

    let tempName = fnameescape(tempname() .".erltrace")
    let srcTempName = fnameescape(tempname() .".exs")

    let txt = substitute(s:traceTemplate, '%%CODE%%', text, 'g')
    let txt = substitute(txt, '%%FILE%%', tempName, 'g')

    call s:writeToFile(txt, srcTempName)

    " save options and locale env variables
    let old_cwd = getcwd()
    execute 'lcd ' . fnameescape(mixDir)

    let mixPrg = "mix run " . fnameescape(srcTempName)

    let errors = s:system(mixPrg)

    execute 'lcd ' . fnameescape(old_cwd)

    " read output of this script into window and bind shortcuts to explore it
    " see zip.vim for Browse function
    "
    " /usr/share/vim/vim80/autoload/zip.vim

    silent! new
    silent! setlocal buftype=nofile noswapfile nobuflisted
    silent! put=errors
    silent! normal ggdd
endfunction " }}}

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

"function s:getPluginDirectory()
"    return expand('<sfile>:p:h')
"endfunction

"function! s:readFile(fName) 
"    silent! new
"    silent! setlocal buftype=nofile bufhidden=hide noswapfile nobuflisted
"    silent! exec "r ".fnameescape(a:fName)
"    let lines = join(getline(1, '$'), "\n")
"    silent! q
"    return lines
"endfunction

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


"augroup ElixirExUnit " {{{
"    au!
"    "au BufWritePost *.ex,*.exs call vimelixirsmarttrace#runExUnitWatchAutoRun()
"augroup END " }}}

" vim: set sw=4 sts=4 et fdm=marker:
"