" Vim syntax file
" Language:  Hack assembly
" Files:     *.hasm  (and *.asm if enabled, see ftdetect/hack.vim)

if exists('b:current_syntax')
  finish
endif

" Anything unrecognised on a line is an error.  Lowest priority: it is defined
" first, and the whole-line items below also start at column 0 and win.
syn match hackasmError /^\s*[^[:space:]\/].*$/

syn match   hackasmComment /\/\/.*$/ contains=hackasmTodo
syn keyword hackasmTodo    contained TODO FIXME XXX NOTE

runtime! syntax/hackasm/elements.vim

syn match hackasmLabelDef /^\s*([A-Za-z_.$:][A-Za-z0-9_.$:]*)/
syn match hackasmAInstr   /^\s*@\s*[A-Za-z0-9_.$:]\+\s*\ze\%(\/\/.*\)\=$/
      \ contains=hackasmAt,hackasmNum,hackasmPre,hackasmSym
syn match hackasmCInstr   /^\s*\%([ADM]\{1,3}\s*=\s*\)\=[-+!&|01ADM ]\+\%(;\s*J\%(GT\|EQ\|GE\|LT\|NE\|LE\|MP\)\)\=\s*\ze\%(\/\/.*\)\=$/
      \ contains=hackasmDest,hackasmEq,hackasmRegC,hackasmCNum,hackasmOp,hackasmSemi,hackasmJump

hi def link hackasmError    Error
hi def link hackasmComment  Comment
hi def link hackasmTodo     Todo

let b:current_syntax = 'hackasm'
