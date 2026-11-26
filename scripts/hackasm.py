#!/usr/bin/env python3
"""
hackasm.py -- assembler and disassembler for the Hack machine language.

  hackasm.py asm  prog.asm  [-o prog.hack] [--listing] [--symbols]
  hackasm.py dis  prog.hack [-o prog.hack.dis] [options]

Use '-' as the input file to read from stdin.  Output goes to stdout unless
-o is given.  Run `hackasm.py asm -h` / `hackasm.py dis -h` for all options.

Instruction formats (see hack_language_spec.md):
  A-instruction   0vvv vvvv vvvv vvvv
  C-instruction   111a cccc ccdd djjj

NOTE: the compute table in the spec lists D-1 as 001111 (same as -D) and D&A
as 000010 (same as D+A).  Those are typos; this tool uses the standard Hack
encodings D-1 = 001110 and D&A = 000000.
"""

import argparse
import re
import sys

# --------------------------------------------------------------------------
# Instruction set tables
# --------------------------------------------------------------------------

# comp mnemonic (a=0 form) -> 6 c-bits.  The a=1 forms are derived by
# replacing A with M.
_COMP_A0 = {
    '0': '101010', '1': '111111', '-1': '111010',
    'D': '001100', 'A': '110000',
    '!D': '001101', '!A': '110001',
    '-D': '001111', '-A': '110011',
    'D+1': '011111', 'A+1': '110111',
    'D-1': '001110', 'A-1': '110010',
    'D+A': '000010', 'D-A': '010011', 'A-D': '000111',
    'D&A': '000000', 'D|A': '010101',
}

COMP = {}  # mnemonic -> (a_bit, 6-bit string)
for _m, _bits in _COMP_A0.items():
    COMP[_m] = (0, _bits)
    if 'A' in _m:
        COMP[_m.replace('A', 'M')] = (1, _bits)
COMP_REV = {v: k for k, v in COMP.items()}

JUMP = {'': 0, 'JGT': 1, 'JEQ': 2, 'JGE': 3, 'JLT': 4, 'JNE': 5, 'JLE': 6, 'JMP': 7}
JUMP_REV = {v: k for k, v in JUMP.items()}

PREDEF = {'R%d' % i: i for i in range(16)}
PREDEF.update({'SP': 0, 'LCL': 1, 'ARG': 2, 'THIS': 3, 'THAT': 4,
               'SCREEN': 0x4000, 'KBD': 0x6000})

SYMBOL_RE = re.compile(r'[A-Za-z_.$:][A-Za-z0-9_.$:]*\Z')
A_MAX = 0x7FFF


# --------------------------------------------------------------------------
# Assembler
# --------------------------------------------------------------------------

def _parse_dest(s):
    if len(set(s)) != len(s) or not set(s) <= set('AMD') or not s:
        raise ValueError("invalid destination '%s'" % s)
    return (4 if 'A' in s else 0) | (2 if 'D' in s else 0) | (1 if 'M' in s else 0)


def _lookup_comp(s):
    if s in COMP:
        return COMP[s]
    # accept commuted operands: M+D, A&D, 1+D, ...
    m = re.fullmatch(r'([^+&|]+)([+&|])([^+&|]+)', s)
    if m:
        swapped = m.group(3) + m.group(2) + m.group(1)
        if swapped in COMP:
            return COMP[swapped]
    raise ValueError("invalid computation '%s'" % s)


def encode_c(code):
    """Encode a whitespace-free C-instruction string to a 16-bit int."""
    dest, comp, jump = '', code, ''
    if '=' in code:
        dest, comp = code.split('=', 1)
        if not dest:
            raise ValueError("empty destination before '='")
    if ';' in comp:
        comp, jump = comp.split(';', 1)
        if jump not in JUMP or not jump:
            raise ValueError("invalid jump '%s' (expected one of %s)"
                             % (jump, ', '.join(k for k in JUMP if k)))
    d = _parse_dest(dest) if dest else 0
    a, c = _lookup_comp(comp)
    return 0xE000 | (a << 12) | (int(c, 2) << 6) | (d << 3) | JUMP[jump]


def assemble(lines, filename='<input>'):
    """Two-pass assemble.

    Returns (rows, symbols, errors).
      rows    -- list of ('label', name) / ('instr', addr, word, code)
      symbols -- dict of user symbols (labels + variables) -> value
      errors  -- list of formatted error strings (empty on success)
    """
    errors = []

    def err(lineno, msg, raw):
        errors.append((lineno, '%s:%d: error: %s\n    %s' % (filename, lineno, msg, raw.strip())))

    # ---- pass 1: labels -------------------------------------------------
    items = []          # (lineno, raw, code)
    labels = {}
    pc = 0
    for lineno, raw in enumerate(lines, 1):
        code = ''.join(raw.split('//', 1)[0].split())
        if not code:
            continue
        if code.startswith('('):
            m = re.fullmatch(r'\(([^()]*)\)', code)
            if not m or not SYMBOL_RE.match(m.group(1)):
                err(lineno, 'malformed label', raw)
            else:
                name = m.group(1)
                if name in labels:
                    err(lineno, "label '%s' already defined (line %d)"
                        % (name, labels[name][1]), raw)
                elif name in PREDEF:
                    err(lineno, "label '%s' collides with a predefined symbol" % name, raw)
                else:
                    labels[name] = (pc, lineno)
                    items.append((lineno, raw, ('label', name)))
            continue
        items.append((lineno, raw, ('instr', code)))
        pc += 1

    # ---- pass 2: encode -------------------------------------------------
    rows = []
    variables = {}
    next_var = 16
    addr = 0
    for lineno, raw, (kind, payload) in items:
        if kind == 'label':
            rows.append(('label', payload))
            continue
        code = payload
        try:
            if code.startswith('@'):
                operand = code[1:]
                if operand.isascii() and operand.isdigit():
                    value = int(operand)
                    if value > A_MAX:
                        raise ValueError('constant %d does not fit in 15 bits (max %d)'
                                         % (value, A_MAX))
                elif SYMBOL_RE.match(operand):
                    if operand in labels:
                        value = labels[operand][0]
                    elif operand in PREDEF:
                        value = PREDEF[operand]
                    else:
                        if operand not in variables:
                            variables[operand] = next_var
                            next_var += 1
                        value = variables[operand]
                else:
                    raise ValueError("invalid A-instruction operand '%s'" % operand)
                word = value
            else:
                word = encode_c(code)
        except ValueError as e:
            err(lineno, str(e), raw)
            word = 0
        rows.append(('instr', addr, word, code))
        addr += 1

    symbols = {k: v[0] for k, v in labels.items()}
    symbols.update(variables)
    return rows, symbols, [e for _, e in sorted(errors, key=lambda e: e[0])]


# --------------------------------------------------------------------------
# Disassembler
# --------------------------------------------------------------------------

def decode(word):
    """Return (kind, text, value). kind is 'A', 'C' or 'bad'."""
    if not word & 0x8000:
        return 'A', '@%d' % word, word
    if (word >> 13) != 0b111:
        return 'bad', '<invalid>', None
    a = (word >> 12) & 1
    c = format((word >> 6) & 0x3F, '06b')
    d = (word >> 3) & 7
    j = word & 7
    comp = COMP_REV.get((a, c))
    if comp is None:
        return 'bad', '<invalid>', None
    dest = ('A' if d & 4 else '') + ('M' if d & 1 else '') + ('D' if d & 2 else '')
    jump = JUMP_REV[j]
    text = (dest + '=' if dest else '') + comp + (';' + jump if jump else '')
    return 'C', text, j


def parse_binary(lines, filename='<input>'):
    """Parse an ascii file of 16-character binary words.

    Tolerates blank lines, // comments, `(LABEL)` lines, an `addr:` prefix and
    spaces inside the word, so that the output of `dis` can be fed back in.
    """
    words, errors = [], []
    for lineno, raw in enumerate(lines, 1):
        text = raw.split('//', 1)[0].strip()
        if not text or (text.startswith('(') and text.endswith(')')):
            continue
        text = re.sub(r'^[0-9A-Fa-f]+:\s*', '', text)
        bits = ''.join(text.split())
        if not re.fullmatch(r'[01]{16}', bits):
            errors.append('%s:%d: error: expected 16 binary digits, got %r'
                          % (filename, lineno, raw.strip()))
            continue
        words.append(int(bits, 2))
    return words, errors


_COLORS = {'addr': '2', 'op': '35', 'val': '36', 'abit': '33',
           'comp': '32', 'dest': '34', 'jump': '31', 'cmt': '2', 'label': '1;33'}


def _paint(text, kind, on):
    return '\033[%sm%s\033[0m' % (_COLORS[kind], text) if on else text


def _fields(word):
    b = format(word, '016b')
    if not word & 0x8000:
        return [('op', b[0]), ('val', b[1:])]
    return [('op', b[0:3]), ('abit', b[3]), ('comp', b[4:10]),
            ('dest', b[10:13]), ('jump', b[13:16])]


def disassemble(words, *, show_addr=True, show_bin=True, split=False,
                labels='mark', regs=False, hex_addr=False, asm_only=False,
                color=False, warn=None):
    """Return a list of output lines."""
    n = len(words)
    decoded = [decode(w) for w in words]

    # jump targets: an A-instruction immediately followed by a jumping C-instr
    targets = set()
    target_ops = set()
    if labels != 'none':
        for i in range(n - 1):
            if decoded[i][0] == 'A' and decoded[i + 1][0] == 'C' and decoded[i + 1][2]:
                t = decoded[i][2]
                if t <= n:
                    targets.add(t)
                    target_ops.add(i)

    def lname(t):
        return 'L%d' % t

    width = max(4, len(('%x' if hex_addr else '%d') % max(n, 1)))
    afmt = '%0*' + ('x' if hex_addr else 'd')

    out = []
    for i, (kind, text, val) in enumerate(decoded):
        if i in targets:
            out.append(_paint('(%s)' % lname(i), 'label', color))
        if kind == 'bad' and warn:
            warn('address %d: 0x%04X is not a valid Hack instruction' % (i, words[i]))
        if kind == 'A':
            if labels == 'sym' and i in target_ops:
                text = '@' + lname(val)
            elif regs:
                if val < 16:
                    text = '@R%d' % val
                elif val == 0x4000:
                    text = '@SCREEN'
                elif val == 0x6000:
                    text = '@KBD'

        if asm_only:
            out.append('    ' + text)
            continue

        prefix = ''
        if show_addr:
            prefix = _paint((afmt % (width, i)) + ':', 'addr', color) + '  '
        if show_bin:
            fields = _fields(words[i])
            sep = ' ' if split else ''
            plain = sep.join(t for _, t in fields)
            colored = sep.join(_paint(t, k, color) for k, t in fields)
            pad = ' ' * ((20 if split else 16) - len(plain))
            out.append('%s%s%s  %s %s' % (prefix, colored, pad,
                                          _paint('//', 'cmt', color), text))
        else:
            out.append(prefix + '    ' + text)
    if n in targets:
        out.append(_paint('(%s)' % lname(n), 'label', color))
    return out


# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------

def _read(path):
    if path == '-':
        return sys.stdin.read().splitlines()
    with open(path, encoding='utf-8') as f:
        return f.read().splitlines()


def _write(lines, path):
    text = '\n'.join(lines) + ('\n' if lines else '')
    if path:
        with open(path, 'w', encoding='utf-8') as f:
            f.write(text)
    else:
        sys.stdout.write(text)


def _fmt_addr(i, width, hexa):
    return ('%0*x' if hexa else '%0*d') % (width, i)


def cmd_asm(args):
    src = _read(args.input)
    name = 'stdin' if args.input == '-' else args.input
    rows, symbols, errors = assemble(src, name)
    if errors:
        print('\n'.join(errors), file=sys.stderr)
        print('%d error(s); no output written.' % len(errors), file=sys.stderr)
        return 1

    if args.symbols:
        for k, v in sorted(symbols.items(), key=lambda kv: (kv[1], kv[0])):
            print('%-20s %5d  0x%04X' % (k, v, v), file=sys.stderr)

    if args.listing:
        n = sum(1 for r in rows if r[0] == 'instr')
        width = max(4, len(('%x' if args.hex_addr else '%d') % max(n, 1)))
        out = []
        for r in rows:
            if r[0] == 'label':
                out.append('(%s)' % r[1])
            else:
                _, addr, word, code = r
                out.append('%s:  %s  // %s' % (_fmt_addr(addr, width, args.hex_addr),
                                              format(word, '016b'), code))
    else:
        out = [format(r[2], '016b') for r in rows if r[0] == 'instr']
    _write(out, args.output)
    return 0


def cmd_dis(args):
    name = 'stdin' if args.input == '-' else args.input
    words, errors = parse_binary(_read(args.input), name)
    if errors:
        print('\n'.join(errors), file=sys.stderr)
        return 1

    labels, show_addr, show_bin = args.labels, not args.no_addr, not args.no_bin
    if args.asm:
        labels, show_addr, show_bin = 'sym', False, False

    color = args.color == 'always' or (args.color == 'auto' and not args.output
                                       and sys.stdout.isatty())
    bad = []
    lines = disassemble(words, show_addr=show_addr, show_bin=show_bin,
                        split=args.split, labels=labels, regs=args.regs,
                        hex_addr=args.hex_addr, asm_only=args.asm, color=color,
                        warn=bad.append)
    if bad and args.asm:
        print('\n'.join('error: ' + b for b in bad), file=sys.stderr)
        print('cannot emit re-assemblable output.', file=sys.stderr)
        return 1
    for b in bad:
        print('warning: ' + b, file=sys.stderr)
    _write(lines, args.output)
    return 0


def main(argv=None):
    p = argparse.ArgumentParser(
        prog='hackasm.py', description='Hack assembler / disassembler')
    sub = p.add_subparsers(dest='cmd', required=True)

    a = sub.add_parser('asm', help='assemble .asm to ascii binary (.hack)')
    a.add_argument('input', help="assembly source, or '-' for stdin")
    a.add_argument('-o', '--output', help='output file (default: stdout)')
    a.add_argument('-l', '--listing', action='store_true',
                   help='emit an objdump-style listing (addr, binary, source) '
                        'instead of bare binary')
    a.add_argument('-s', '--symbols', action='store_true',
                   help='print the symbol table (labels and variables) to stderr')
    a.add_argument('-X', '--hex-addr', action='store_true',
                   help='hex addresses in --listing')
    a.set_defaults(func=cmd_asm)

    d = sub.add_parser('dis', help='disassemble ascii binary (.hack)')
    d.add_argument('input', help="binary file of 16-bit words, or '-' for stdin")
    d.add_argument('-o', '--output', help='output file (default: stdout)')
    d.add_argument('--no-addr', action='store_true', help='omit the address column')
    d.add_argument('-X', '--hex-addr', action='store_true', help='hex addresses')
    d.add_argument('--no-bin', action='store_true', help='omit the binary column')
    d.add_argument('-S', '--split', action='store_true',
                   help='split binary into fields: "0 vvv..." / "111 a cccccc ddd jjj"')
    d.add_argument('--labels', choices=['none', 'mark', 'sym'], default='mark',
                   help="jump-target labels: 'none'; 'mark' (default) inserts "
                        "(Lnn) lines but keeps numeric operands; 'sym' also "
                        "rewrites the jump operands as @Lnn")
    d.add_argument('-r', '--regs', action='store_true',
                   help='print @0..@15 as @R0..@R15, @16384 as @SCREEN, @24576 as @KBD')
    d.add_argument('--asm', action='store_true',
                   help='emit bare, re-assemblable assembly (implies --labels sym, '
                        '--no-addr, --no-bin)')
    d.add_argument('--color', choices=['auto', 'always', 'never'], default='auto',
                   help='ANSI colors for the terminal (default: auto)')
    d.set_defaults(func=cmd_dis)

    args = p.parse_args(argv)
    try:
        return args.func(args)
    except FileNotFoundError as e:
        print('error: %s' % e, file=sys.stderr)
        return 1
    except BrokenPipeError:
        return 0


if __name__ == '__main__':
    sys.exit(main())
