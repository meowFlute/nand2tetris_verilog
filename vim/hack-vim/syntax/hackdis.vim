" Vim syntax file
" Language:  Hack disassembly / listing  (as printed by `hackasm.py dis`
"            or `hackasm.py asm --listing`)
" Files:     *.hack.dis  *.hack.lst
"
"   0005:  1111110000010000  // D=M
"   (L4)
"   0007:  111 1 010011 010 000  // D=D-M         (with --split)
"
" The binary is coloured per field (syntax/hack.vim); everything after "//" is
" highlighted as Hack assembly using the shared tokens in
" syntax/hackasm/elements.vim.  (No :syn include is used on purpose.)

if exists('b:current_syntax')
  finish
endif

runtime! syntax/hack.vim
unlet! b:current_syntax

runtime! syntax/hackasm/elements.vim

" "(LABEL)" lines
syn match hackasmLabelDef /^\s*([A-Za-z_.$:][A-Za-z0-9_.$:]*)/

syn match hackDisInvalid /<invalid>/ contained

" the assembly column; overrides the plain comment from hack.vim
syn region hackDisAsm matchgroup=hackDisSep start=+//\s*+ end=+$+ oneline keepend
      \ contains=hackasmAt,hackasmNum,hackasmPre,hackasmSym,hackasmDest,hackasmEq,
      \ hackasmRegC,hackasmCNum,hackasmOp,hackasmSemi,hackasmJump,hackDisInvalid

hi def link hackDisSep     Comment
hi def link hackDisInvalid Error

let b:current_syntax = 'hackdis'
