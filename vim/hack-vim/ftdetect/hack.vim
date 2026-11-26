" Filetype detection for the Hack machine language.
"
"   *.hack                  binary (ascii 1s and 0s)          -> hack
"   *.hack.dis, *.hack.lst  disassembly / listing             -> hackdis
"   *.hasm                  Hack assembly                     -> hackasm
"   *.asm                   Hack assembly, ONLY if you opt in  -> hackasm
"
" Opt in for .asm files (vim would otherwise treat them as x86/etc. asm):
"     let g:hack_asm_detect_dot_asm = 1     " sniff content of *.asm files
"     let g:hack_asm_detect_dot_asm = 2     " treat every *.asm as Hack
" Or per file, put this on any line:   // vim: ft=hackasm
" Or by hand:                          :set ft=hackasm

autocmd BufRead,BufNewFile *.hack.dis,*.hack.lst setfiletype hackdis
autocmd BufRead,BufNewFile *.hack                setfiletype hack
autocmd BufRead,BufNewFile *.hasm                setfiletype hackasm

function! s:LooksLikeHackAsm() abort
  let l:mode = get(g:, 'hack_asm_detect_dot_asm', 0)
  if l:mode == 2
    return 1
  elseif l:mode != 1
    return 0
  endif
  let l:hits = 0
  for l:line in getline(1, 200)
    let l:line = substitute(l:line, '//.*$', '', '')
    " x86 / ARM / GNU-as style content => not Hack
    if l:line =~# '^\s*\%(\.\w\+\|section\|global\|extern\|mov\|push\|pop\|lea\|call\|ret\|bl\|ldr\|str\)\>'
      return 0
    endif
    if l:line =~# '^\s*@[A-Za-z0-9_.$:]\+\s*$'
          \ || l:line =~# '^\s*([A-Za-z_.$:][A-Za-z0-9_.$:]*)\s*$'
          \ || l:line =~# '^\s*\%([AMD]\{1,3}=\)\=[-+!&|01ADM]\+;J\%(GT\|EQ\|GE\|LT\|NE\|LE\|MP\)\s*$'
      let l:hits += 1
    endif
  endfor
  return l:hits >= 2
endfunction

autocmd BufRead,BufNewFile *.asm if s:LooksLikeHackAsm() | set filetype=hackasm | endif
