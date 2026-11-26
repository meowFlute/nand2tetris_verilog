" Vim syntax file
" Language:  Hack machine language, binary (ascii 1s and 0s)
" Files:     *.hack   (also reused by the hackdis syntax)
"
" A-instruction:  0 vvvvvvvvvvvvvvv
" C-instruction:  111 a cccccc ddd jjj
"
" Tolerates an optional "addr:" prefix and single spaces between the fields,
" which is what `hackasm.py dis` prints (with or without --split).
"
" Implementation note: the fields are chained with nextgroup= rather than
" each being anchored with ^.  A ^-anchored pattern can only match at column
" 0, so once the "addr:" item has consumed the start of the line nothing
" anchored could match any more.

if exists('b:current_syntax')
  finish
endif

let s:sp  = '\s\='
let s:b1  = '[01]'
let s:b3  = '[01]\{3}'
let s:b6  = '[01]\{6}'
let s:b15 = '[01]\{15}'
" what must follow the opcode for the line to be a well-formed 16-bit word
let s:restA = s:sp . s:b15 . '\>'
let s:restC = s:sp . s:b1 . s:sp . s:b6 . s:sp . s:b3 . s:sp . s:b3 . '\>'

" ---- field chain (contained: reached only through nextgroup) -------------
exe 'syn match hackAOp /0\ze'   . s:restA . '/ contained nextgroup=hackAVal skipwhite'
syn match hackAVal   /[01]\{15}/             contained
exe 'syn match hackCOp /111\ze' . s:restC . '/ contained nextgroup=hackCA skipwhite'
syn match hackCA     /[01]/                  contained nextgroup=hackCComp skipwhite
syn match hackCComp  /[01]\{6}/              contained nextgroup=hackCDest skipwhite
syn match hackCDest  /[01]\{3}/              contained nextgroup=hackCJump skipwhite
syn match hackCJump  /[01]\{3}/              contained
" first three bits 100/101/110: not a legal instruction
exe 'syn match hackBad /1\%(0[01]\|10\)\ze' . s:restC . '/ contained'

" ---- entry points ---------------------------------------------------------
" a line with an address column: "0004:" then the chain
syn match hackAddr /^\s*\x\+:/ nextgroup=hackAOp,hackCOp,hackBad skipwhite
" a line that starts directly with the binary word
exe 'syn match hackAOpL /^\s*\zs0\ze'   . s:restA . '/ nextgroup=hackAVal skipwhite'
exe 'syn match hackCOpL /^\s*\zs111\ze' . s:restC . '/ nextgroup=hackCA skipwhite'
exe 'syn match hackBadL /^\s*\zs1\%(0[01]\|10\)\ze' . s:restC . '/'

syn match   hackComment /\/\/.*$/ contains=hackTodo
syn keyword hackTodo    contained TODO FIXME XXX NOTE

hi def link hackAOp     Statement
hi def link hackAOpL    Statement
hi def link hackCOp     Statement
hi def link hackCOpL    Statement
hi def link hackAVal    Number
hi def link hackCA      Type
hi def link hackCComp   Constant
hi def link hackCDest   Identifier
hi def link hackCJump   Special
hi def link hackBad     Error
hi def link hackBadL    Error
hi def link hackAddr    LineNr
hi def link hackComment Comment
hi def link hackTodo    Todo

unlet s:sp s:b1 s:b3 s:b6 s:b15 s:restA s:restC
let b:current_syntax = 'hack'
