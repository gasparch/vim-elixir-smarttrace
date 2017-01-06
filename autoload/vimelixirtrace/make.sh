#!/bin/bash


EXS=`cat generate_dump.exs | sed -e 's/\\\/\\\\\\\\/g' -e 's/"/\\\\"/g' -e 's/$/\\\\n/g' -e 's/^/    \\\\/'`


cat > dump.vim <<EOF
" AUTOGENERATED BY dump.sh, do not edit
function! vimelixirtrace#dump#dump(fname, code, testSpec)

	let txt = "\n
$EXS
\"

	let tempName = fnameescape(a:fname)

	let txt = substitute(txt, '%%CODE%%', a:code, 'g')
	let txt = substitute(txt, '%%FILE%%', tempName, 'g')
	let txt = substitute(txt, '%%TEST_SPEC%%', a:testSpec, 'g')

	return txt
endfunction
EOF

cat dump.vim

#cat generate_dump.exs | sed -e 's/%%CODE%%/MapUtils.deep_merge(%{a: 123, b: %{c: 123}}, %{b: %{c: 123123}})/g' -e 's/%%FILE%%/tmpfile.erltrace/' > test.exs
