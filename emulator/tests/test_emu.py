#!/usr/bin/env python3
"""Tests for hackemu: known programs, loader tolerance, debug map, and a fuzz
comparison against an independent Python reference model of the CPU.

  make test          (from the hackemu directory; builds first)
"""
import os
import random
import re
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
HACKASM = os.environ.get('HACKASM') or os.path.join(ROOT, '..', 'hackasm.py')
EMU = os.path.join(ROOT, 'hackemu')
sys.path.insert(0, os.path.dirname(os.path.abspath(HACKASM)))
import hackasm as H  # noqa: E402

TMP = tempfile.mkdtemp(prefix='hackemu-test-')
failures = 0


def check(name, ok, detail=''):
    global failures
    print('%s  %s' % ('ok  ' if ok else 'FAIL', name))
    if not ok:
        failures += 1
        if detail:
            print('      ' + detail.replace('\n', '\n      '))


def run(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, **kw)


def assemble(asm, name, debug=True):
    out = os.path.join(TMP, name + '.hack')
    cmd = [sys.executable, HACKASM, 'asm', asm, '-o', out] + (['-g'] if debug else [])
    r = run(cmd)
    assert r.returncode == 0, r.stderr
    return out


def ram_values(stdout):
    return {int(m.group(1)): int(m.group(2)) for m in
            re.finditer(r'RAM\[\s*(\d+)\] =\s+(-?\d+)', stdout)}


# ---- 1. Mult --------------------------------------------------------------
mult = assemble(os.path.join(HERE, 'Mult.asm'), 'Mult')
for a, b in [(3, 4), (0, 5), (7, 0), (12, 12), (1, 100), (-3, 5)]:
    r = run([EMU, '-m', mult + '.map', '-r', 'R0=%d' % a, '-r', 'R1=%d' % b, '-d', 'R2', mult])
    got = ram_values(r.stdout).get(2)
    want = ((a * b) + 32768) % 65536 - 32768
    check('Mult %d*%d = %d' % (a, b, want), r.returncode == 0 and got == want,
          'rc=%d got=%r\n%s' % (r.returncode, got, r.stderr))

# ---- 2. semantics ---------------------------------------------------------
sem = assemble(os.path.join(HERE, 'semantics.asm'), 'semantics')
r = run([EMU, '-d', '0:3', '-d', '7:8', '-d', '10', sem])
v = ram_values(r.stdout)
want = {0: 11, 1: 2, 2: -1, 3: -32768, 7: 0, 8: 0, 10: 11}
check('AM= uses old A; jump uses old A; signed jumps', r.returncode == 0 and v == want,
      'got %r\nwant %r\n%s' % (v, want, r.stderr))

# ---- 3. loader accepts disassembler output --------------------------------
for flags in ([], ['-S'], ['--no-addr'], ['-X', '-S']):
    dis = os.path.join(TMP, 'Mult.dis')
    run([sys.executable, HACKASM, 'dis', mult, '-o', dis] + flags)
    r = run([EMU, '-r', 'R0=6', '-r', 'R1=7', '-d', 'R2', dis])
    check('loads `dis %s` output' % ' '.join(flags), ram_values(r.stdout).get(2) == 42, r.stderr)

# ---- 4. debug map ---------------------------------------------------------
m = open(mult + '.map').read().splitlines()
check('map: header, 20 line records, labels, var',
      m[0] == '# hackmap 1' and sum(1 for x in m if x.startswith('line ')) == 20
      and 'label LOOP 4' in m and 'label END 18' in m and 'var i 16' in m, '\n'.join(m))
r = run([EMU, '-m', mult + '.map', '-b', 'LOOP', '-t', '-r', 'R1=2', mult])
check('breakpoint by label stops at it (rc 3, PC=4)', r.returncode == 3 and 'PC=4' in r.stderr,
      r.stdout[-300:] + r.stderr)
r = run([EMU, '-n', '10', mult])
check('cycle limit (rc 2)', r.returncode == 2, r.stderr)
r = run([EMU, os.path.join(TMP, 'nope.hack')])
check('missing file (rc 1)', r.returncode == 1)

bad = os.path.join(TMP, 'bad.hack')
open(bad, 'w').write('0000000000000001\n1000000000000000\n')
r = run([EMU, bad])
check('invalid instruction (rc 5)', r.returncode == 5, r.stderr)
open(bad, 'w').write('0000000000000001\n0000000000000010\n')
r = run([EMU, bad])
check('running off the end of the program (rc 4)', r.returncode == 4, r.stderr)

# ---- 5. screen + keyboard -------------------------------------------------
scr = os.path.join(TMP, 'scr.asm')
open(scr, 'w').write('@KBD\nD=M\n@SCREEN\nM=D\n@16\nM=1\n@21\n(E)\n@E\n0;JMP\n')
out = assemble(scr, 'scr', debug=False)
pbm = os.path.join(TMP, 'out.pbm')
r = run([EMU, '-k', '65', '-p', pbm, out])
rows = open(pbm).read().split('\n')[2:]
# 65 = 0b1000001 -> pixels 0 and 6 of the first row
check('keyboard word read, screen word written, PBM output',
      rows[0][:8] == '10000010' and rows[0][8:] == '0' * 504, rows[0][:20])

# ---- 6. fuzz against the reference model ---------------------------------
def ref_run(rom, max_cycles):
    ram = {}
    pc = a = d = cyc = 0
    trace = []
    while True:
        if cyc >= max_cycles:
            return trace, 2, ram
        if pc >= len(rom):
            return trace, 4, ram
        ins = rom[pc]
        mval = ram.get(a, 0) if a <= 24576 else 0
        trace.append('%7d  PC=%04X  %04X  A=%04X D=%04X M=%04X' % (cyc, pc, ins, a, d, mval))
        if not ins & 0x8000:
            a, pc, cyc = ins, (pc + 1) & 0x7FFF, cyc + 1
            continue
        if ins & 0x6000 != 0x6000:
            return trace, 5, ram
        abit, cbits = (ins >> 12) & 1, format((ins >> 6) & 63, '06b')
        dest, jmp = (ins >> 3) & 7, ins & 7
        if (abit or dest & 1) and a > 24576:
            return trace, 6, ram
        expr = H.COMP_REV[(abit, cbits)].replace('!', '~')
        out = eval(expr, {}, {'A': a, 'D': d, 'M': mval}) & 0xFFFF
        old_a = a
        if dest & 1 and old_a != 24576:
            ram[old_a] = out
        if dest & 2:
            d = out
        if dest & 4:
            a = out
        s = out - 65536 if out >= 32768 else out
        taken = (jmp & 4 and s < 0) or (jmp & 2 and s == 0) or (jmp & 1 and s > 0)
        target = old_a & 0x7FFF
        nxt = target if taken else (pc + 1) & 0x7FFF
        cyc += 1
        halted = jmp == 7 and (target == pc or (target + 1 == pc and target < len(rom) and rom[target] == target))
        pc = nxt
        if halted:
            return trace, 0, ram


rng = random.Random(1234)
status_count, total_cycles = {}, 0
comps = sorted(H.COMP)
A_POOL = list(range(0, 40)) + [16384, 16385, 16415, 24575, 24576, 24577, 30000, 32767]
bad_cases = 0
N_FUZZ = 400
for case in range(N_FUZZ):
    n = rng.randint(4, 60)
    rom = []
    for _ in range(n):
        if rng.random() < 0.35:
            rom.append(rng.choice(A_POOL) if rng.random() < 0.6 else rng.randint(0, n))
        else:
            abit_comp = H.COMP[rng.choice(comps)]
            rom.append(0xE000 | (abit_comp[0] << 12) | (int(abit_comp[1], 2) << 6)
                       | (rng.randint(0, 7) << 3) | rng.randint(0, 7))
    path = os.path.join(TMP, 'fuzz.hack')
    open(path, 'w').write('\n'.join(format(w, '016b') for w in rom) + '\n')
    r = run([EMU, '-n', '600', '-t', '-d', '0:40', '-d', '16384:16415', path])
    ctrace = [l for l in r.stdout.splitlines() if 'PC=' in l]
    cram = {k: v & 0xFFFF for k, v in ram_values(r.stdout).items()}
    rtrace, rrc, rram = ref_run(rom, 600)
    want_ram = {a: rram.get(a, 0) for a in list(range(0, 41)) + list(range(16384, 16416))}
    status_count[rrc] = status_count.get(rrc, 0) + 1
    total_cycles += len(rtrace)
    if ctrace != rtrace or r.returncode != rrc or cram != want_ram:
        bad_cases += 1
        if bad_cases <= 3:
            i = next((i for i, (x, y) in enumerate(zip(ctrace, rtrace)) if x != y), min(len(ctrace), len(rtrace)))
            print('      case %d: rc C=%d ref=%d; first trace difference at line %d' % (case, r.returncode, rrc, i))
            print('        C  : %s' % (ctrace[i] if i < len(ctrace) else '<none>'))
            print('        ref: %s' % (rtrace[i] if i < len(rtrace) else '<none>'))
check('fuzz: %d random programs match the reference model' % N_FUZZ, bad_cases == 0,
      '%d mismatching programs' % bad_cases)

print('      fuzz coverage: exit statuses %s, %d instructions compared' % (dict(sorted(status_count.items())), total_cycles))
print('\n%s' % ('all tests passed' if not failures else '%d FAILED' % failures))
sys.exit(1 if failures else 0)
