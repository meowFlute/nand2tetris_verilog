" Shared assembly-token items for syntax/hackasm.vim and syntax/hackdis.vim.
" Loaded with :runtime! (NOT :syn include), so every item below simply
" belongs to the current buffer's syntax.  All are "contained": the caller
" lists the ones it wants in its own contains=.
"
" Order matters: when two items start at the same column the later one wins.

syn match hackasmCNum  /\<[01]\>/                  contained
syn match hackasmRegC  /\<[ADM]\>/                 contained
syn match hackasmDest  /\<[ADM]\{1,3}\ze\s*=/      contained
syn match hackasmOp    /[-+!&|]/                   contained
syn match hackasmEq    /=/                         contained
syn match hackasmSemi  /;/                         contained
syn match hackasmJump  /\%(;\s*\)\@<=J\%(GT\|EQ\|GE\|LT\|NE\|LE\|MP\)\>/ contained
syn match hackasmAt    /@/                         contained
syn match hackasmSym   /@\@<=[A-Za-z_.$:][A-Za-z0-9_.$:]*/ contained
syn match hackasmPre   /@\@<=\%(R\%(1[0-5]\|\d\)\|SP\|LCL\|ARG\|THIS\|THAT\|SCREEN\|KBD\)\%([A-Za-z0-9_.$:]\)\@!/ contained
syn match hackasmNum   /@\@<=\d\+/                 contained

" Colours deliberately line up with the binary groups in syntax/hack.vim:
" dest = Identifier, comp = Constant, jump = Special, value = Number.
hi def link hackasmAt       Statement
hi def link hackasmNum      Number
hi def link hackasmPre      PreProc
hi def link hackasmSym      String
hi def link hackasmDest     Identifier
hi def link hackasmRegC     Constant
hi def link hackasmCNum     Constant
hi def link hackasmOp       Operator
hi def link hackasmEq       Delimiter
hi def link hackasmSemi     Delimiter
hi def link hackasmJump     Special
hi def link hackasmLabelDef Label
