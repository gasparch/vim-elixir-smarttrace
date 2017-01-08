
let s:highlightMatch = 0
function! vimelixirtrace#erltrace#highlightMatch() "{{{
    let ln = getline('.')

    let matches = matchlist(ln, '^\([A-Z]\):\(\d\+\): \(\S\+\) ')

    if len(matches) == 0
        return
    endif

    if s:highlightMatch
        silent! call matchdelete(s:highlightMatch)
        let s:highlightMatch = 0
    endif

    let direction = 'nW'
    if matches[3] == 'call'
        let pair = ['call', 'ret']
    elseif matches[3] == 'ret'
        let pair = ['call', 'ret']
        let direction .= 'b'
    elseif matches[3] == 'handle_call'
        let pair = ['handle_call', '⤶handle_call']
    elseif matches[3] == '⤶handle_call'
        let pair = ['handle_call', '⤶handle_call']
        let direction .= 'b'
    endif

    let prefix = '^' . matches[1] . ':' . matches[2] . ': '

    let [matchLnNum, ignoreCol] = searchpairpos(prefix . pair[0], '', prefix . pair[1], direction)

    if matchLnNum == 0
        return
    endif

    let currentNum = line('.')

    let s:highlightMatch = matchadd('MatchParen', '^\%(\%'. matchLnNum .'l\|\%'.currentNum.'l\)[A-Z]\+:\d\+: \S\+', 16, -1)
endfunction " }}}

function! vimelixirtrace#erltrace#foldLevel(lineNum) " {{{
    "let foldLevel = foldlevel(a:lineNum)
    let ln = getline(a:lineNum)

    if ln =~ '^    '
        return 1
    endif

    return 0
endfunction " }}}

function! vimelixirtrace#erltrace#foldText() " {{{
    let line = getline(v:foldstart)
    let sub = substitute(line, '❟,❟', ',', 'g')
    return v:folddashes . sub
endfunction " }}}

function! vimelixirtrace#erltrace#findFileName(lineNum, bang) " {{{
    let ln = getline(a:lineNum)

    let fun_name = ''
    let optionalPattern = ''
    if ln =~ '^\w\+\:\d\+\: call' || ln =~ '^\w\+\:\d\+\: ret'
        let matches = matchlist(ln, '^\S\+ \%(call\|ret\)\s*\(\S\+\) ')

        if len(matches) == 0
            return
        endif
        let fun_name = matches[1]
    elseif ln =~ '^\w\+\:\d\+\: .\?handle_call'
        let matches = matchlist(ln, '^\S\+ .\?handle_call \(\S\+\) \(.*\)$')

        if len(matches) == 0
            return
        endif
        let fun_name = matches[1].":handle_call/3"

        let atom_in_args = matchlist(matches[2], ':[a-z_]\+')
        if len(atom_in_args) > 0
            let optionalPattern = 'def\s\+handle_call\s*(.*'.atom_in_args[0]
        endif
    endif

    let fun_parsed = matchlist(fun_name, '^\([:]\?\%(\w\|[.]\)\+\):\(\%([-\/]\|\w\)*\)/\([0-9]\+\)')

    if len(fun_parsed) == 0 | return | endif

    let key = fun_parsed[1].":".fun_parsed[2].":".fun_parsed[3]


    let mapping = vimelixirsmarttrace#getModuleFunLines()

    if !has_key(mapping, key) | return | endif

    let [ lineNo, fileName ] = mapping[key]

    call vimelixirsmarttrace#openInOriginalWindow(fileName, lineNo, optionalPattern, a:bang == '!')
endfunction " }}}

function! vimelixirtrace#erltrace#navigateSameFunc(direction) " {{{
    let lineNo = line('.')
    let oldLineNo = line('.')
    let ln = getline(lineNo)

    " skip all indented lines (with arguments) backwards
    while (ln =~ '^\s\+' || ln =~ '^\C\%([A-Z]\+\)>[A-Z]\+:') && lineNo > 0
        let lineNo -= 1
        let ln = getline(lineNo)
    endwhile

    let matches = split(ln, '[ :]\+')

    if len(matches) == 0 | return | endif

    "" skip send messages
    "if matches[0] !~ '^[:alpha]\+$'
    "    return
    "endif

    let takeLen = (matches[2] =~ 'handle_' ? 3 : 4)
    let matches[1] = '\d\+'
    let matches[2] = '\s\+[⤶]\?\w\+'
    let searchRegexp = join(matches[0:takeLen], '\%(\s\+\|:\)')

    let flags = (a:direction == 'back' ? 'bW' : 'W')
    call search(searchRegexp, flags)
endfunction " }}}

function! vimelixirtrace#erltrace#navigateFunc(direction) " {{{
    let searchRegexp = '^\C\%([A-Z]\+\):\d\+:\s\+[⤶]\?\w\+\s\+'

    let flags = (a:direction == 'back' ? 'bW' : 'W')
    call search(searchRegexp, flags)
endfunction " }}}

function! vimelixirtrace#erltrace#navigateSkipFunc(direction) " {{{
    let lineNo = line('.')
    let oldLineNo = line('.')
    let ln = getline(lineNo)

    " skip all indented lines (with arguments) backwards
    while (ln =~ '^\s\+' || ln =~ '^\C\%([A-Z]\+\)>[A-Z]\+:') && lineNo > 0
        let lineNo -= 1
        let ln = getline(lineNo)
    endwhile

    let matches = split(ln, '[ :]\+')

    if len(matches) == 0 | return | endif

    let takeLen = (matches[2] =~ 'handle_' ? 3 : 4)
    let matches[1] = '\d\+'
    let matches[2] = '\s\+[⤶]\?\w\+'
    let searchRegexp = join(matches[0:takeLen], '\%(\s\+\|:\)')

    let step = a:direction == 'back' ? -1 : 1
    let maxLines = line('$') + 1
    let lineNo += step
    let ln = getline(lineNo)

    while (lineNo > 1 && lineNo < maxLines) &&
                \ (ln =~ '^\s\+' || ln =~ '^\C\%([A-Z]\+\)>[A-Z]\+:' ||
                \  ln =~ searchRegexp)
        let lineNo += step
        let ln = getline(lineNo)
    endwhile

    call cursor(lineNo, 1)
endfunction " }}}

function! vimelixirtrace#erltrace#toggleFold() " {{{
    let lineNo = line('.')
    let ln = getline(lineNo)

    let searchRegexp = '^\C\%([A-Z]\+\):\d\+:\s\+[⤶]\?\w\+.*«⋯$'
    if foldlevel(lineNo) == 0 && ln =~ searchRegexp
        call s:toggleFold(lineNo + 1)
    else
        call s:toggleFold(lineNo)
    endif
endfunction " }}}

function! s:toggleFold(lineNo) " {{{
    if foldlevel(a:lineNo) == 0
        normal! l
    else
        if foldclosed(a:lineNo) < 0
            exec a:lineNo."foldclose"
        else
            exec a:lineNo."foldopen"
        endif
    endif
endfunction " }}}
