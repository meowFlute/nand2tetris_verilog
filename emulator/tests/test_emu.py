#!/usr/bin/env python3
"""Tests for the headless Hack emulator (hackemu).

  make test                                   run everything (builds first)
  make test TESTFLAGS=-v                      list each test as it runs
  python3 -m unittest tests.test_emu.FillTests          one group
  python3 -m unittest tests.test_emu.FillTests.test_full_pass_cycle_count
  HACKEMU_FUZZ=5000 make test                 a longer fuzz run

Environment:  HACKASM (path to hackasm.py), HACKEMU (path to the binary),
              HACKEMU_FUZZ (number of random programs, default 400).

Test programs: tests/Mult.asm and tests/Fill.asm are symlinks to src/chapter_4/;
semantics.asm lives here.  Most other tests build their ROM directly in Python so
the expected values come from Python arithmetic, not from the C core under test.
"""
import os
import random
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
HACKASM = os.environ.get('HACKASM') or os.path.join(ROOT, '..', 'scripts', 'hackasm.py')
EMU = os.environ.get('HACKEMU') or os.path.join(ROOT, 'hackemu')
FUZZ_N = int(os.environ.get('HACKEMU_FUZZ', '400'))

sys.path.insert(0, os.path.dirname(os.path.abspath(HACKASM)))
import hackasm as H  # noqa: E402

SCREEN, KBD, SCREEN_WORDS = 16384, 24576, 8192
# exit statuses of hackemu
RC_HALT, RC_USAGE, RC_MAX, RC_BREAK, RC_END, RC_BADINS, RC_BADADDR = range(7)

TMP = None
PROGS = {}


# ---------------------------------------------------------------- helpers --

class Result:
    def __init__(self, proc):
        self.rc, self.out, self.err = proc.returncode, proc.stdout, proc.stderr
        self.ram = {int(a): int(v) for a, v in
                    re.findall(r'RAM\[\s*(\d+)\] =\s+(-?\d+)', self.out)}
        m = re.search(r'after (\d+) cycles, PC=(\d+)', self.err)
        self.cycles = int(m.group(1)) if m else None
        self.pc = int(m.group(2)) if m else None

    def screen(self):
        return [self.ram[SCREEN + i] & 0xFFFF for i in range(SCREEN_WORDS)]


def emu(prog, *args):
    """Run hackemu on a program; returns a Result."""
    cmd = [EMU] + [str(a) for a in args] + [prog]
    return Result(subprocess.run(cmd, capture_output=True, text=True))


def assemble(asm_path, name, debug=True):
    out = os.path.join(TMP, name + '.hack')
    cmd = [sys.executable, HACKASM, 'asm', asm_path, '-o', out] + (['-g'] if debug else [])
    p = subprocess.run(cmd, capture_output=True, text=True)
    if p.returncode:
        raise RuntimeError('assembling %s failed:\n%s' % (asm_path, p.stderr))
    return out


def write_rom(words, name):
    path = os.path.join(TMP, name + '.hack')
    write_text(path, '\n'.join(format(w, '016b') for w in words) + '\n')
    return path


def write_text(path, text):
    with open(path, 'w') as f:
        f.write(text)


def read_text(path):
    with open(path) as f:
        return f.read()


def screen_diff(words, expected):
    """Compact description of how a screen differs from `expected` (an int that
    every word should equal, or a list), or None if identical.  Used instead of
    assertEqual on 8192-word lists, whose failure diff takes minutes to compute."""
    if isinstance(expected, int):
        expected = [expected] * len(words)
    diffs = [i for i, (w, e) in enumerate(zip(words, expected)) if w != e]
    if not diffs and len(words) == len(expected):
        return None
    shown = ', '.join('word %d: got 0x%04X want 0x%04X' % (i, words[i], expected[i])
                      for i in diffs[:4])
    return '%d of %d screen words differ (%s%s)' % (
        len(diffs), len(expected), shown, ', ...' if len(diffs) > 4 else '')


def signed(v):
    v &= 0xFFFF
    return v - 65536 if v & 0x8000 else v


def setUpModule():
    global TMP
    if not os.path.exists(EMU):
        raise RuntimeError('%s not built (run `make`)' % EMU)
    TMP = tempfile.mkdtemp(prefix='hackemu-test-')
    for name in ('Mult', 'Fill', 'semantics'):
        PROGS[name] = assemble(os.path.join(HERE, name + '.asm'), name)


def tearDownModule():
    shutil.rmtree(TMP, ignore_errors=True)


# --------------------------------------------------------- real programs --

class MultTests(unittest.TestCase):
    def test_products(self):
        for a, b in [(3, 4), (0, 5), (7, 0), (12, 12), (1, 100), (-3, 5), (200, 150)]:
            with self.subTest(a=a, b=b):
                r = emu(PROGS['Mult'], '-m', PROGS['Mult'] + '.map',
                        '-r', 'R0=%d' % a, '-r', 'R1=%d' % b, '-d', 'R2')
                self.assertEqual(r.rc, RC_HALT, r.err)
                self.assertEqual(r.ram[2], signed(a * b))

    def test_inputs_are_preserved(self):
        r = emu(PROGS['Mult'], '-r', 'R0=9', '-r', 'R1=6', '-d', 'R0:2')
        self.assertEqual((r.ram[0], r.ram[1], r.ram[2]), (9, 6, 54))

    def test_cycle_count_is_deterministic(self):
        # 3*4 always costs the same number of instructions; guards against
        # accidental changes to step()/halt detection
        r = emu(PROGS['Mult'], '-r', 'R0=3', '-r', 'R1=4')
        self.assertEqual((r.rc, r.cycles), (RC_HALT, 68), r.err)


class ScreenMixin:
    def assertScreen(self, r, expected):
        self.assertIsNone(screen_diff(r.screen(), expected))


class FillTests(ScreenMixin, unittest.TestCase):
    """Fill.asm polls the keyboard and paints the 8K-word screen black or white.

    One full pass costs 14 (LOOP -> set-up) + 15 * 8192 (FILL_LOOP body) + 6 (the
    exit test) = 122900 instructions, and lands back on LOOP.  A key press or
    release is only noticed when a pass finishes.
    """
    PASS = 14 + 15 * SCREEN_WORDS + 6
    MAP = None

    @classmethod
    def setUpClass(cls):
        cls.MAP = PROGS['Fill'] + '.map'

    def fill(self, *args):
        return emu(PROGS['Fill'], '-m', self.MAP, '-d', 'SCREEN:24575',
                   '-d', 'ARG', '-d', 'curr_address', *args)

    def test_pass_length(self):
        r = self.fill('-k', 1, '-b', 'LOOP', '-n', 1000000)
        self.assertEqual((r.rc, r.pc, r.cycles), (RC_BREAK, 0, self.PASS), r.err)

    def test_key_blackens_the_whole_screen(self):
        r = self.fill('-k', 65, '-b', 'LOOP', '-d', 'KBD')
        self.assertScreen(r, 0xFFFF)
        self.assertEqual(r.ram[2], -1)                # ARG = value being written
        self.assertEqual(r.ram[16], KBD)              # curr_address stopped at KBD
        self.assertEqual(r.ram[KBD], 65)              # program never touches the keyboard

    def test_no_key_clears_a_dirty_screen(self):
        # first, middle and last word, so an off-by-one at either end would show
        r = self.fill('-r', 'SCREEN=-1', '-r', '20000=0x1234', '-r', '24575=-1', '-b', 'LOOP')
        self.assertEqual(r.rc, RC_BREAK, r.err)
        self.assertScreen(r, 0)
        self.assertEqual(r.ram[2], 0)
        self.assertEqual(r.ram[16], KBD)

    def test_partial_fill_progress(self):
        k = 100                                       # words written so far
        r = self.fill('-k', 1, '-n', 14 + 15 * k)
        self.assertScreen(r, [0xFFFF] * k + [0] * (SCREEN_WORDS - k))
        self.assertEqual(r.ram[16], SCREEN + k)

    def test_press_after_start_blackens_on_a_later_pass(self):
        r = self.fill('-K', '5000=65', '-n', 2 * self.PASS)
        self.assertEqual(r.rc, RC_MAX)
        self.assertScreen(r, 0xFFFF)

    def test_release_clears_on_a_later_pass(self):
        r = self.fill('-k', 65, '-K', '1000=0', '-n', 3 * self.PASS)
        self.assertScreen(r, 0)
        self.assertEqual(r.ram[2], 0)

    def test_key_is_only_sampled_between_passes(self):
        # released at cycle 1000, but the first pass was already painting black
        r = self.fill('-k', 65, '-K', '1000=0', '-b', 'LOOP')
        self.assertEqual(r.cycles, self.PASS)
        self.assertScreen(r, 0xFFFF)


class SemanticsTests(unittest.TestCase):
    def test_semantics_program(self):
        r = emu(PROGS['semantics'], '-d', '0:3', '-d', '7:8', '-d', '10')
        self.assertEqual(r.rc, RC_HALT, r.err)
        # AM= writes at the OLD A; jumps use the A from before the instruction;
        # signed compares; 0x4000 + 0x4000 wraps to -32768
        self.assertEqual({a: r.ram[a] for a in (0, 1, 2, 3, 7, 8, 10)},
                         {0: 11, 1: 2, 2: -1, 3: -32768, 7: 0, 8: 0, 10: 11})


# ----------------------------------------------------- table-driven CPU --

ALL_D = [0, 1, -1, 0x7FFF, 0x8000, 0x1234]


class AluTests(unittest.TestCase):
    """Every comp mnemonic, against edge values, with the expected result computed
    by evaluating the mnemonic in Python (no shared code with the C ALU)."""

    @staticmethod
    def one(comp, d, a, m):
        # 0:@0  1:D=M  2:@a  3:D=<comp>  4:@1  5:M=D  6:@6  7:0;JMP   (halts at 7)
        rom = [0, H.encode_c('D=M'), a, H.encode_c('D=' + comp), 1,
               H.encode_c('M=D'), 6, H.encode_c('0;JMP')]
        path = write_rom(rom, 'alu_%s' % abs(hash((comp, d, a, m))))
        args = ['-r', 'R0=%d' % d, '-d', 'R1']
        if m is not None:
            args += ['-r', '%d=%d' % (a, m)]
        r = emu(path, *args)
        os.unlink(path)
        want = eval(comp.replace('!', '~'), {}, {
            'D': d & 0xFFFF, 'A': a, 'M': (m or 0) & 0xFFFF}) & 0xFFFF
        return comp, d, a, m, r, signed(want)

    def test_all_comps(self):
        jobs = []
        for comp in H.COMP:
            if 'M' in comp:
                jobs += [(comp, d, 5, m) for d in ALL_D for m in (0, -1, 0x7FFF, 0x8001)]
            else:
                jobs += [(comp, d, a, None) for d in ALL_D for a in (5, 0x7FFF)]
        with ThreadPoolExecutor(8) as ex:
            results = list(ex.map(lambda j: self.one(*j), jobs))
        bad = [(c, d, a, m, r.ram.get(1), w) for c, d, a, m, r, w in results
               if r.rc != RC_HALT or r.ram.get(1) != w]
        self.assertEqual(bad, [], 'first failures (comp, D, A, M, got, want): %r' % bad[:5])
        self.assertEqual(len(results), len(jobs))


class JumpTests(unittest.TestCase):
    """Each jump condition against negative, zero and positive ALU output."""
    COND = {'JGT': lambda v: v > 0, 'JEQ': lambda v: v == 0, 'JGE': lambda v: v >= 0,
            'JLT': lambda v: v < 0, 'JNE': lambda v: v != 0, 'JLE': lambda v: v <= 0,
            'JMP': lambda v: True}

    def test_jump_matrix(self):
        # 0:@0 1:D=M 2:@8 3:D;Jxx 4:@1 5:M=1 6:@10 7:0;JMP | 8:@1 9:M=-1 | 10:@10 11:0;JMP
        for jump, cond in self.COND.items():
            rom = [0, H.encode_c('D=M'), 8, H.encode_c('D;' + jump), 1, H.encode_c('M=1'),
                   10, H.encode_c('0;JMP'), 1, H.encode_c('M=-1'), 10, H.encode_c('0;JMP')]
            path = write_rom(rom, 'jump_' + jump)
            for d in (-32768, -1, 0, 1, 32767):
                with self.subTest(jump=jump, D=d):
                    r = emu(path, '-r', 'R0=%d' % d, '-d', 'R1')
                    self.assertEqual(r.rc, RC_HALT, r.err)
                    self.assertEqual(r.ram[1], -1 if cond(d) else 1)    # -1 = taken

    def test_no_jump_when_field_is_empty(self):
        # 0:@0 1:D=M 2:@99 3:D 4:@1 5:M=1  -- whatever D is, execution falls through
        rom = [0, H.encode_c('D=M'), 99, H.encode_c('D'), 1, H.encode_c('M=1')]
        for d in (-5, 0, 5):
            with self.subTest(D=d):
                r = emu(write_rom(rom, 'nojump'), '-r', 'R0=%d' % d, '-d', 'R1')
                self.assertEqual((r.rc, r.ram[1]), (RC_END, 1), r.err)


# ----------------------------------------------------- loader / map / CLI --

class LoaderTests(unittest.TestCase):
    def test_loads_disassembler_output(self):
        for flags in ([], ['-S'], ['--no-addr'], ['-X', '-S'], ['--labels', 'sym', '-r']):
            with self.subTest(flags=flags):
                dis = os.path.join(TMP, 'Mult.dis')
                p = subprocess.run([sys.executable, HACKASM, 'dis', PROGS['Mult'],
                                    '-o', dis] + flags, capture_output=True, text=True)
                self.assertEqual(p.returncode, 0, p.stderr)
                r = emu(dis, '-r', 'R0=6', '-r', 'R1=7', '-d', 'R2')
                self.assertEqual(r.ram.get(2), 42, r.err)

    def test_rejects_malformed_lines(self):
        path = os.path.join(TMP, 'malformed.hack')
        for text in ('101\n', '0000000000000001x\n', '00000000000000012\n'):
            with self.subTest(text=text):
                write_text(path, text)
                r = emu(path)
                self.assertEqual(r.rc, RC_USAGE)
                self.assertIn(':1:', r.err)

    def test_missing_file(self):
        self.assertEqual(emu(os.path.join(TMP, 'nope.hack')).rc, RC_USAGE)


class MapTests(unittest.TestCase):
    def test_mult_map_contents(self):
        m = read_text(PROGS['Mult'] + '.map').splitlines()
        self.assertEqual(m[0], '# hackmap 1')
        self.assertEqual(sum(1 for x in m if x.startswith('line ')), 20)
        for want in ('label LOOP 4', 'label END 18', 'var i 16'):
            self.assertIn(want, m)

    def test_fill_map_contents(self):
        m = read_text(PROGS['Fill'] + '.map').splitlines()
        self.assertIn('label LOOP 0', m)
        self.assertIn('var curr_address 16', m)
        for label in ('SET_SCREEN', 'FILL_LOOP', 'CLEAR_SCREEN', 'BLACKEN_SCREEN'):
            self.assertTrue(any(x.startswith('label %s ' % label) for x in m), label)

    def test_map_source_path_resolves(self):
        first = [x for x in read_text(PROGS['Mult'] + '.map').splitlines() if x.startswith('file 0 ')][0]
        rel = first.split(' ', 2)[2].strip()
        self.assertTrue(os.path.exists(os.path.join(TMP, rel)), rel)

    def test_trace_shows_source_lines_and_labels(self):
        r = emu(PROGS['Mult'], '-m', PROGS['Mult'] + '.map', '-t', '-n', 8)
        self.assertRegex(r.out.splitlines()[0], r'Mult\.asm:5')
        self.assertTrue(any('<LOOP>' in l for l in r.out.splitlines()))

    def test_symbols_usable_everywhere(self):
        r = emu(PROGS['Mult'], '-m', PROGS['Mult'] + '.map', '-b', 'END', '-d', 'i')
        self.assertEqual((r.rc, r.pc), (RC_BREAK, 18))
        self.assertEqual(r.ram[16], 0)             # `i` is a variable at RAM[16]; unused here, so 0


class CliTests(unittest.TestCase):
    def test_exit_codes(self):
        self.assertEqual(emu(PROGS['Mult'], '-n', 10).rc, RC_MAX)
        self.assertEqual(emu(PROGS['Mult'], '-b', 'LOOP').rc, RC_USAGE)     # no map: unknown symbol
        bad = write_rom([1, 0x8000], 'badins')
        self.assertEqual(emu(bad).rc, RC_BADINS)
        end = write_rom([1, 2], 'end')
        self.assertEqual(emu(end).rc, RC_END)

    def test_bad_m_address_is_reported(self):
        # @24577 ; M=1  -> M access beyond the keyboard word
        r = emu(write_rom([24577, H.encode_c('M=1')], 'badaddr'))
        self.assertEqual(r.rc, RC_BADADDR, r.err)
        # ... but A=24577 alone is fine, and so is D=A
        r = emu(write_rom([24577, H.encode_c('D=A')], 'a_only'))
        self.assertEqual(r.rc, RC_END, r.err)

    def test_keyboard_word_is_read_only(self):
        # @KBD ; M=-1 must not change the keyboard word
        r = emu(write_rom([KBD, H.encode_c('M=-1')], 'kbdwrite'), '-k', 7, '-d', 'KBD')
        self.assertEqual(r.ram[KBD], 7)

    def test_bad_arguments(self):
        for args in (['-r', 'nonsense'], ['-r', 'R99=1'], ['-K', 'x'], ['-K', '5=70000'],
                     ['-d', 'NOSUCH'], ['--bogus']):
            with self.subTest(args=args):
                self.assertEqual(emu(PROGS['Mult'], *args).rc, RC_USAGE)

    def test_help(self):
        p = subprocess.run([EMU, '--help'], capture_output=True, text=True)
        self.assertEqual(p.returncode, 0)
        self.assertIn('--key-at', p.stdout)

    def test_pbm_output(self):
        asm = os.path.join(TMP, 'pbm.asm')
        write_text(asm, '@KBD\nD=M\n@SCREEN\nM=D\n@16\nM=1\n@21\n(E)\n@E\n0;JMP\n')
        prog = assemble(asm, 'pbm', debug=False)
        pbm = os.path.join(TMP, 'out.pbm')
        self.assertEqual(emu(prog, '-k', 65, '-p', pbm).rc, RC_HALT)
        lines = read_text(pbm).split('\n')
        self.assertEqual(lines[:2], ['P1', '512 256'])
        self.assertEqual(lines[2], '10000010' + '0' * 504)       # 65 = 0b1000001, LSB leftmost
        self.assertEqual(len(lines[2:]), 256 + 1)                # 256 rows + trailing newline
        self.assertEqual(lines[3], '0' * 512)


class KeyEventTests(unittest.TestCase):
    """--key-at CYCLE=CODE: the key changes once CYCLE instructions have run."""

    @classmethod
    def setUpClass(cls):
        # (L) @KBD  D=M  @R0  M=D  @L  0;JMP      six instructions per iteration
        asm = os.path.join(TMP, 'echo.asm')
        write_text(asm, '(L)\n@KBD\nD=M\n@0\nM=D\n@L\n0;JMP\n')
        cls.prog = assemble(asm, 'echo', debug=False)

    def r0(self, *args):
        return emu(self.prog, '-d', 'R0', *args).ram[0]

    def test_event_not_reached(self):
        # first read of KBD after cycle 10 is at cycle 13, its store at 15
        self.assertEqual(self.r0('-K', '10=7', '-n', 12), 0)

    def test_event_applies(self):
        self.assertEqual(self.r0('-K', '10=7', '-n', 20), 7)

    def test_two_events_in_order(self):
        self.assertEqual(self.r0('-K', '10=7', '-K', '20=9', '-n', 20), 7)
        self.assertEqual(self.r0('-K', '10=7', '-K', '20=9', '-n', 30), 9)

    def test_events_may_be_given_out_of_order(self):
        self.assertEqual(self.r0('-K', '20=9', '-K', '10=7', '-n', 30), 9)

    def test_release(self):
        self.assertEqual(self.r0('-k', 5, '-K', '10=0', '-n', 30), 0)

    def test_same_result_with_trace(self):
        a = self.r0('-K', '10=7', '-K', '20=9', '-n', 30)
        b = emu(self.prog, '-t', '-K', '10=7', '-K', '20=9', '-n', 30, '-d', 'R0').ram[0]
        self.assertEqual(a, b)


# ------------------------------------------------------------------ fuzz --

def ref_run(rom, max_cycles):
    """Independent reference model; returns (trace lines, exit status, sparse RAM)."""
    ram = {}
    pc = a = d = cyc = 0
    trace = []
    while True:
        if cyc >= max_cycles:
            return trace, RC_MAX, ram
        if pc >= len(rom):
            return trace, RC_END, ram
        ins = rom[pc]
        mval = ram.get(a, 0) if a <= KBD else 0
        trace.append('%7d  PC=%04X  %04X  A=%04X D=%04X M=%04X' % (cyc, pc, ins, a, d, mval))
        if not ins & 0x8000:
            a, pc, cyc = ins, (pc + 1) & 0x7FFF, cyc + 1
            continue
        if ins & 0x6000 != 0x6000:
            return trace, RC_BADINS, ram
        abit, cbits = (ins >> 12) & 1, format((ins >> 6) & 63, '06b')
        dest, jmp = (ins >> 3) & 7, ins & 7
        if (abit or dest & 1) and a > KBD:
            return trace, RC_BADADDR, ram
        out = eval(H.COMP_REV[(abit, cbits)].replace('!', '~'), {},
                   {'A': a, 'D': d, 'M': mval}) & 0xFFFF
        old_a = a
        if dest & 1 and old_a != KBD:
            ram[old_a] = out
        if dest & 2:
            d = out
        if dest & 4:
            a = out
        s = signed(out)
        taken = (jmp & 4 and s < 0) or (jmp & 2 and s == 0) or (jmp & 1 and s > 0)
        target = old_a & 0x7FFF
        nxt = target if taken else (pc + 1) & 0x7FFF
        cyc += 1
        halted = jmp == 7 and (target == pc or
                               (target + 1 == pc and target < len(rom) and rom[target] == target))
        pc = nxt
        if halted:
            return trace, RC_HALT, ram


class FuzzTests(unittest.TestCase):
    A_POOL = list(range(40)) + [SCREEN, SCREEN + 1, SCREEN + 31, 24575, KBD, KBD + 1, 30000, 32767]

    def test_random_programs_match_reference_model(self):
        rng = random.Random(1234)
        comps = sorted(H.COMP)
        statuses, compared, bad = {}, 0, []
        path = os.path.join(TMP, 'fuzz.hack')
        for case in range(FUZZ_N):
            n = rng.randint(4, 60)
            rom = []
            for _ in range(n):
                if rng.random() < 0.35:
                    rom.append(rng.choice(self.A_POOL) if rng.random() < 0.6 else rng.randint(0, n))
                else:
                    a_bit, c = H.COMP[rng.choice(comps)]
                    rom.append(0xE000 | (a_bit << 12) | (int(c, 2) << 6)
                               | (rng.randint(0, 7) << 3) | rng.randint(0, 7))
            write_rom(rom, 'fuzz')
            r = emu(path, '-n', 600, '-t', '-d', '0:40', '-d', '%d:%d' % (SCREEN, SCREEN + 31))
            ctrace = [l for l in r.out.splitlines() if 'PC=' in l]
            rtrace, rrc, rram = ref_run(rom, 600)
            want = {a: signed(rram.get(a, 0)) for a in list(range(41)) + list(range(SCREEN, SCREEN + 32))}
            statuses[rrc] = statuses.get(rrc, 0) + 1
            compared += len(rtrace)
            if ctrace != rtrace or r.rc != rrc or r.ram != want:
                i = next((i for i, (x, y) in enumerate(zip(ctrace, rtrace)) if x != y),
                         min(len(ctrace), len(rtrace)))
                bad.append((case, r.rc, rrc, i, ctrace[i:i + 1], rtrace[i:i + 1]))
        self.assertEqual(bad[:3], [], '%d of %d programs differ' % (len(bad), FUZZ_N))
        self.assertGreater(compared, 25 * FUZZ_N)             # the programs ran for a while
        if FUZZ_N >= 100:
            self.assertGreaterEqual(len(statuses), 3)         # and ended in varied ways


if __name__ == '__main__':
    unittest.main()
