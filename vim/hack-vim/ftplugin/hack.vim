" Filetype plugin: Hack binary (*.hack)
if exists('b:did_ftplugin') | finish | endif
let b:did_ftplugin = 1

setlocal nowrap
setlocal commentstring=//\ %s
setlocal comments=://

" :HackDis  -- show a disassembly of this buffer in a vertical split
command! -buffer HackDis call hackasm#Run('dis')

let b:undo_ftplugin = 'setlocal wrap< commentstring< comments< | delcommand HackDis'
