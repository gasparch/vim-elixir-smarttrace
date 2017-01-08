if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

if has("gui_running")
  syntax match EOFStart "«⋯"
  syntax match EOFEnd "⋯»"
  syntax match ReturnValue "⤶"
  syntax match MessageSend "→"
  syntax match MessageRecv "←"
  syntax match MessageDeadProcess "^\w\+→☠\w\+"
  " not sure which one is better, non-concealed version does not allow normal
  " copy, but provides better visibility
  syntax match CommaMarkup "❟,❟" contains=Comma,CommaMarks
  syntax match CommaMarks  ",❟" conceal contained
  syntax match Comma "❟" contained
else
  syntax match EOFStart "«⋯" conceal cchar=<
  syntax match EOFEnd "⋯»" conceal cchar=>
  syntax match ReturnValue "⤶" conceal cchar=< contained
  syntax match MessageSend "→" conceal cchar=>
  syntax match MessageRecv "←" conceal cchar=<
  syntax match MessageDeadProcess "^\w\+→☠\w\+"
  " not sure which one is better, non-concealed version does not allow normal
  " copy, but provides better visibility
  syntax match CommaMarkup "❟,❟" contains=Comma,CommaMarks
  syntax match CommaMarks  "❟" conceal contained
  syntax match Comma "," contained
endif


syntax match PidMarkup "\"ꜝ\w\+\"" contains=PidName,PidMarks
syntax match PidMarks  "[ꜝ\"]" conceal contained
syntax keyword PidName "ꜝ\@<=\w\+"
syntax match GenServerCalls "\%(^\w\+:\d\+: \|\w\+→\w\+: \)\@<=\(\S\?handle_call\|GenServer.\w\+\)" contains=ReturnValue
syntax match CallTrace "\%(^\w\+:\d\+: \)\@<=\(call\|ret\)"

syntax match FoldedArguments '^\s\+.*' contains=EOFEnd,CommaMarkup

hi link MessageDeadProcess  Error
hi link EOFStart            Comment
hi link EOFEnd              Comment
hi link ReturnValue         Comment
hi link MessageSend         Comment
hi link MessageRecv         Comment

hi link Comma               elixirAtom
hi link PidMarkup           Statement

hi link GenServerCalls      Statement
hi link CallTrace           Function
hi link FoldedArguments     Identifier

let b:current_syntax = "erltrace"

let &cpo = s:cpo_save
unlet s:cpo_save
