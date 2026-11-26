" Filetype plugin: Hack disassembly / listing (*.hack.dis)
if exists('b:did_ftplugin') | finish | endif
let b:did_ftplugin = 1

setlocal nowrap
setlocal commentstring=//\ %s
setlocal comments=://

let b:undo_ftplugin = 'setlocal wrap< commentstring< comments<'
