" Filetype plugin: Hack assembly (*.hasm)
if exists('b:did_ftplugin') | finish | endif
let b:did_ftplugin = 1

setlocal commentstring=//\ %s
setlocal comments=://
setlocal expandtab shiftwidth=4 softtabstop=4

" :HackAsm  -- assemble this buffer, show the listing in a vertical split
command! -buffer HackAsm call hackasm#Run('asm')

let b:undo_ftplugin = 'setlocal commentstring< comments< expandtab< shiftwidth< softtabstop< | delcommand HackAsm'
