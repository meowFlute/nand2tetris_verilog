" Helpers for running hackasm.py on the current buffer.
"
"   g:hackasm_path      path to hackasm.py             (default: 'hackasm.py')
"   g:hackasm_dis_args  extra args for `dis`           (default: '--split')
"   g:hackasm_asm_args  extra args for `asm`           (default: '--listing')
"
" If hackasm.py is not on $PATH:  let g:hackasm_path = 'python3 ~/bin/hackasm.py'

function! hackasm#Run(mode) abort
  let l:prog = get(g:, 'hackasm_path', 'hackasm.py')
  let l:args = get(g:, 'hackasm_' . a:mode . '_args', a:mode ==# 'dis' ? '--split' : '--listing')
  let l:out  = systemlist(l:prog . ' ' . a:mode . ' ' . l:args . ' -', getline(1, '$'))
  if v:shell_error
    echohl ErrorMsg | echom join(l:out, "\n") | echohl None
    return
  endif
  let l:src = expand('%:t')
  vertical new
  setlocal buftype=nofile bufhidden=wipe noswapfile
  call setline(1, l:out)
  let &l:filetype = 'hackdis'
  silent! file `=l:src . '.' . (a:mode ==# 'dis' ? 'dis' : 'lst')`
  setlocal nomodifiable nowrap
  normal! gg
endfunction
