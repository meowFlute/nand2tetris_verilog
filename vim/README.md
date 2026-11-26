# Hack language support for Vim

Filetype detection, syntax highlighting and a couple of helper commands for the
[Hack](https://www.nand2tetris.org/) machine language used in nand2tetris. It
covers three kinds of file:

| Extension | Filetype | What it is |
|---|---|---|
| `*.hack` | `hack` | Machine code: one 16-character line of `0`s and `1`s per instruction |
| `*.hack.dis`, `*.hack.lst` | `hackdis` | A disassembly or listing: address, binary, and the assembly as a `//` comment |
| `*.hasm` | `hackasm` | Hack assembly source (`*.asm` too, if you opt in, see [Options](#options)) |

Highlighting colors each *field* of the binary (opcode, a-bit, comp, dest, jump), and
in `.hack.dis` files it also highlights the assembly to the right of each word, using
matching colors.

The assembler and disassembler themselves are in `hackasm.py`, a separate
single-file Python script. Nothing here needs it except the optional `:HackDis` and
`:HackAsm` commands.

---

## Contents of this folder

```
README.md                    this file
ftdetect/hack.vim            maps file extensions to filetypes
syntax/hack.vim              highlighting for binary (.hack), also reused by hackdis
syntax/hackdis.vim           highlighting for disassembly / listing files
syntax/hackasm.vim           highlighting for assembly source
syntax/hackasm/elements.vim  assembly tokens shared by hackasm and hackdis
ftplugin/hack.vim            settings for .hack, defines :HackDis
ftplugin/hackdis.vim         settings for .hack.dis
ftplugin/hackasm.vim         settings for .hasm (4-space indent), defines :HackAsm
autoload/hackasm.vim         the code behind :HackDis and :HackAsm
examples/                    Mult in each format, for trying out the colors
```

This is a standard Vim runtime layout, so the folder can be used as-is as a Vim
package or runtime directory. Do not rename the subdirectories.

---

## Installing

Requirements: Vim 8+ or Neovim, with `syntax on` and `filetype plugin on` (the
default in Neovim; in Vim put `syntax on` and `filetype plugin indent on` in your
vimrc if you don't already have them).

In the commands below, `HACKVIM` is the path to **this folder** inside your clone
of the repo, for example `HACKVIM=~/nand2tetris_verilog/vim`.

### Option 1: package, symlinked from the repo (recommended)

A symlink means `git pull` on a laptop updates Vim automatically.

Vim:

```sh
mkdir -p ~/.vim/pack/hack/start
ln -s "$HACKVIM" ~/.vim/pack/hack/start/hack
```

Neovim:

```sh
mkdir -p "${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/pack/hack/start"
ln -s "$HACKVIM" "${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/pack/hack/start/hack"
```

### Option 2: one line in your vimrc

No symlink, just point Vim at the folder. Put this **before** any
`filetype plugin on` line:

```vim
set runtimepath+=~/nand2tetris_verilog/vim
```

(Neovim: the same line works in `init.vim`; in `init.lua` use
`vim.opt.runtimepath:append("~/nand2tetris_verilog/vim")`.)

### Option 3: copy

Copy the contents of this folder (not the folder itself) into `~/.vim/`
(or `~/.config/nvim/`). You then have to repeat the copy to update.

### Putting `hackasm.py` on your PATH (only for `:HackDis` / `:HackAsm`)

```sh
chmod +x hackasm.py
ln -s "$(pwd)/hackasm.py" ~/.local/bin/hackasm.py     # any directory on $PATH
```

If you'd rather not touch your PATH, tell Vim where it is instead:

```vim
let g:hackasm_path = 'python3 ~/nand2tetris_verilog/tools/hackasm.py'
```

### Checking it worked

Open a file from `examples/`, then:

```vim
:set filetype?        " should say hack, hackdis or hackasm
:scriptnames          " should list this folder's files
```

### Uninstalling

Remove the symlink (Option 1), the `runtimepath` line (Option 2), or the copied
files (Option 3).

---

## Making the files

```sh
hackasm.py asm Mult.asm -o Mult.hack                 # assemble
hackasm.py dis Mult.hack -o Mult.hack.dis            # disassemble, default layout
hackasm.py dis Mult.hack -S -o Mult.hack.dis         # ... with fields split apart
hackasm.py asm Mult.asm --listing -o Mult.hack.lst   # listing straight from source
```

Name the output `*.hack.dis` or `*.hack.lst` and Vim picks up the right filetype.
By default no terminal color codes are written to a file or pipe (`--color auto`), so
the files stay clean; don't pass `--color always` when saving.

What the highlighting understands in a `hackdis` file:

```
0007:  1111010011010000  // D=D-M        address, binary word, assembly comment
0007:  111 1 010011 010 000  // D=D-M    same, with `dis --split` / `-S`
(L4)                                    label lines inserted by `dis` / `--listing`
```

Hex addresses (`dis -X`) work too. `dis --no-addr` also works (a line may start
directly with the binary word). `dis --no-bin` output has no binary column and no `//`,
so it is not a `hackdis` file; use `dis --asm` and save that as `.hasm` instead.

---

## Commands

| Command | Available in | Does |
|---|---|---|
| `:HackDis` | `.hack` buffers | Disassembles the buffer into a read-only vertical split (filetype `hackdis`) |
| `:HackAsm` | `.hasm` buffers | Assembles the buffer and shows the listing in a vertical split |

Both feed the *buffer contents* to `hackasm.py` through stdin, so unsaved edits are
included. Errors from the assembler are shown as a Vim error message and no split
is opened.

---

## Options

Set these in your vimrc.

| Variable | Default | Effect |
|---|---|---|
| `g:hack_asm_detect_dot_asm` | `0` | `0`: `*.asm` is left to Vim (x86 etc.). `1`: sniff the first 200 lines of each `*.asm` and use `hackasm` only if it looks like Hack (`@x`, `(LABEL)`, `D;JMP` lines, and no x86/ARM-style content). `2`: every `*.asm` is Hack |
| `g:hackasm_path` | `hackasm.py` | Command used by `:HackDis` / `:HackAsm`. May include an interpreter, e.g. `python3 ~/bin/hackasm.py` |
| `g:hackasm_dis_args` | `--split` | Extra arguments for `:HackDis` |
| `g:hackasm_asm_args` | `--listing` | Extra arguments for `:HackAsm` |

For a single `.asm` file without turning on detection, add `// vim: ft=hackasm` on
a line near the top (assuming modelines are on), or type `:set ft=hackasm`.

---

## Tweaking the colors

Every color is set with `highlight default link`, so it follows your colorscheme and
you can override any of it. Switching colorschemes clears overrides, so apply them
in a `ColorScheme` autocmd:

```vim
augroup hack_colors
  autocmd!
  autocmd ColorScheme * highlight link hackCJump Todo
  autocmd ColorScheme * highlight hackCComp ctermfg=173 guifg=#d7875f
augroup END
```

(Put the `augroup` **before** your `colorscheme` line so it also runs the first time.)

### Binary fields: `syntax/hack.vim`, used by `.hack` and `.hack.dis`

| Group | Part of the word | Links to |
|---|---|---|
| `hackAOp`, `hackAOpL` | A-instruction opcode (`0`) | `Statement` |
| `hackAVal` | The 15-bit value | `Number` |
| `hackCOp`, `hackCOpL` | C-instruction opcode (`111`) | `Statement` |
| `hackCA` | The `a` bit | `Type` |
| `hackCComp` | The 6 comp bits | `Constant` |
| `hackCDest` | The 3 dest bits | `Identifier` |
| `hackCJump` | The 3 jump bits | `Special` |
| `hackBad`, `hackBadL` | An illegal opcode (`100`, `101`, `110`) | `Error` |
| `hackAddr` | The `0007:` address column | `LineNr` |
| `hackComment`, `hackTodo` | `//` comments | `Comment`, `Todo` |

The `...L` variants are the same field when the line starts directly with the binary
(no address column). If you set colors directly rather than with `highlight link`,
set both variants. Linking them to the same group avoids this.

### Assembly: `syntax/hackasm/elements.vim`, used by `.hasm` and `.hack.dis`

| Group | Part of the assembly | Links to |
|---|---|---|
| `hackasmAt` | The `@` | `Statement` |
| `hackasmNum` | `@16` (numeric operand) | `Number` |
| `hackasmPre` | `@R0`..`@R15`, `@SP`, `@LCL`, `@ARG`, `@THIS`, `@THAT`, `@SCREEN`, `@KBD` | `PreProc` |
| `hackasmSym` | `@i`, `@LOOP` (variables and labels) | `String` |
| `hackasmDest` | `D`, `M`, `AM`, ... before `=` | `Identifier` |
| `hackasmRegC`, `hackasmCNum` | `A` `D` `M` and `0` `1` in the comp part | `Constant` |
| `hackasmOp` | `+ - & \| !` | `Operator` |
| `hackasmEq`, `hackasmSemi` | `=` and `;` | `Delimiter` |
| `hackasmJump` | `JGT` .. `JMP` | `Special` |
| `hackasmLabelDef` | `(LABEL)` | `Label` |
| `hackasmComment`, `hackasmTodo` | `//` comments | `Comment`, `Todo` |
| `hackasmError` | A line that is not valid assembly | `Error` |

The palette is deliberately parallel: dest is `Identifier` in both the binary and the
assembly, comp is `Constant`, jump is `Special`, values are `Number`, so the three
bits and the letters they stand for are the same color.

Also in `hackdis`: `hackDisSep` (the `//` before the assembly, `Comment`) and
`hackDisInvalid` (`<invalid>`, `Error`).

### Adding another assembly token

Add a `syn match ... contained` line to `syntax/hackasm/elements.vim`, link it with
`hi def link`, and add the group name to the `contains=` lists in `syntax/hackasm.vim`
(`hackasmAInstr` or `hackasmCInstr`) and `syntax/hackdis.vim` (the `hackDisAsm`
region).

---

## How the files work (for when you change something)

- **`ftdetect/hack.vim`** uses `setfiletype` for the unambiguous extensions. For
  `*.asm` it uses `set filetype=` after Vim's own detection, so it can override it.
- **`syntax/hack.vim`** does not anchor each field with `^`. The fields are chained
  with `nextgroup=` starting from the address column (or from the start of the line if
  there is none). Anchored patterns cannot match after the address item has already
  consumed the start of the line, which is why they are chained.
- **`syntax/hackdis.vim`** loads `hack.vim` for the binary, loads
  `hackasm/elements.vim` for the assembly tokens, and puts everything after `//` in a
  region that contains those tokens. It does not use `:syn include`.
- **Comments**: Hack uses `//`, and the ftplugins set `commentstring` to match, so
  comment plugins such as vim-commentary work.

---

## Troubleshooting

| Symptom | Check |
|---|---|
| No colors at all | `:set filetype?` and `:syntax` (should say `syntax on`). If the filetype is empty, the plugin isn't on the runtimepath: `:scriptnames` |
| Wrong filetype for `.asm` | See `g:hack_asm_detect_dot_asm`, or `:set ft=hackasm` |
| Binary colored but assembly after `//` is plain | `:syn list hackDisAsm` should show `contains=` followed by the `hackasm...` groups |
| Which group is under the cursor? | `:echo synIDattr(synID(line('.'), col('.'), 1), 'name')` |
| Colors disappear after `:colorscheme` | Use the `ColorScheme` autocmd shown above |
| `:HackDis` says command not found | `hackasm.py` is not on `$PATH`; set `g:hackasm_path` |
| A `.hack` line is not colored | It is probably not exactly 16 `0`/`1` characters; colors apply only to well-formed words |

When reporting a problem, the output of `:syn list` in the affected buffer is the most
useful thing to include.
