#!/usr/bin/env python3

"""Generate a Verilog test harness skeleton for a module in rtl/chapter_*/.

Usage:
    scripts/generate_test.py and_gate                       # full truth table, blank expected values
    scripts/generate_test.py                                # pick list of every module in every chapter
    scripts/generate_test.py -c 2                           # pick list limited to chapter_2
    scripts/generate_test.py alu -n 20                      # 20 fully blank cases (for wide buses)
    scripts/generate_test.py dff -s                         # clock-driven: tick_and_check task, 4 blank cycles
    scripts/generate_test.py register -s -n 8               # clock-driven with 8 blank cycles
    scripts/generate_test.py foo -s --clock-name clock      # point out the clock input name explicitly

The chapter is taken from where the module lives: rtl/chapter_N/<module>.v
produces test/chapter_N/test_<module>.v. Expected values (and, in sampled
mode, the inputs too) are left blank so the file won't compile until you
fill them in.
"""

import argparse
import itertools
import re
import sys
from dataclasses import dataclass
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
MAX_EXHAUSTIVE_INPUT_BITS = 10  # 1024 cases; beyond this, require -n
DEFAULT_SEQ_CASES = 4           # in sequential cases a truth table doesn't make much sense, 
                                # so by default it'll generate 4 tick and check cases 


@dataclass
class Port:
    name: str
    direction: str  # "input" or "output"
    width: int


# ---------------------------------------------------------------- parsing

def strip_comments(text):
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    return re.sub(r"//[^\n]*", "", text)


def parse_ports(source, module_name):
    """Parse an ANSI-style port list. Bus widths must be numeric literals."""
    src = strip_comments(source)
    m = re.search(
        rf"\bmodule\s+{re.escape(module_name)}\s*\((.*?)\)\s*;", src, re.S
    )
    if not m:
        raise ValueError(f"could not find 'module {module_name} (...);' in source")

    ports = []
    direction, width = None, 1
    for chunk in m.group(1).split(","):
        chunk = chunk.strip()
        if not chunk:
            continue
        dm = re.match(r"(input|output|inout)\b", chunk)
        if dm:
            direction = dm.group(1)
            if direction == "inout":
                raise ValueError("inout ports are not supported")
            wm = re.search(r"\[\s*(\d+)\s*:\s*(\d+)\s*\]", chunk)
            if "[" in chunk and not wm:
                raise ValueError(f"non-numeric bus width in: {chunk!r}")
            width = abs(int(wm.group(1)) - int(wm.group(2))) + 1 if wm else 1
        elif direction is None:
            raise ValueError("only ANSI-style port declarations are supported")
        # else: bare name inheriting direction/width from the previous chunk

        idents = re.findall(r"[A-Za-z_]\w*", re.sub(r"\[[^\]]*\]", "", chunk))
        ports.append(Port(idents[-1], direction, width))

    if not any(p.direction == "input" for p in ports):
        raise ValueError("module has no inputs")
    if not any(p.direction == "output" for p in ports):
        raise ValueError("module has no outputs")
    return ports


# -------------------------------------------------------- module selection

def natural_key(s):
    """Sort chapter_2 before chapter_10."""
    return [int(t) if t.isdigit() else t for t in re.split(r"(\d+)", s)]


def chapter_matches(dir_name, wanted):
    """wanted may be None, a bare number ("2"), or a dir name ("chapter_2")."""
    if wanted is None:
        return True
    if wanted.isdigit():
        m = re.fullmatch(r"chapter_(\d+)", dir_name)
        return bool(m) and int(m.group(1)) == int(wanted)
    return dir_name == wanted


def find_modules(rtl_dir, chapter=None):
    """Return [(chapter_dir_name, module_name, path)], sorted by chapter then name."""
    found = [
        (p.parent.name, p.stem, p)
        for p in rtl_dir.glob("chapter_*/*.v")
        if chapter_matches(p.parent.name, chapter)
    ]
    return sorted(found, key=lambda t: (natural_key(t[0]), t[1]))


def choose_module(rtl_dir, test_dir, chapter=None):
    entries = find_modules(rtl_dir, chapter)
    if not entries:
        where = f"chapter {chapter}" if chapter else "rtl/chapter_*"
        sys.exit(f"error: no .v files found for {where} under {rtl_dir}")
    if not sys.stdin.isatty():
        sys.exit("error: no module given and stdin is not interactive")

    print("Modules:")
    current = None
    for i, (ch, name, _) in enumerate(entries, 1):
        if ch != current:
            print(f"  {ch}/")
            current = ch
        status = "test exists" if (test_dir / ch / f"test_{name}.v").exists() else "no test yet"
        print(f"    {i:2d}) {name:<24} [{status}]")
    choice = input("Pick a number or name: ").strip()

    if choice.isdigit() and 1 <= int(choice) <= len(entries):
        return entries[int(choice) - 1]
    matches = [e for e in entries if e[1] == choice]
    if len(matches) == 1:
        return matches[0]
    if len(matches) > 1:
        sys.exit(f"error: {choice!r} exists in several chapters; pick by number")
    sys.exit(f"error: invalid selection {choice!r}")


def resolve_module(rtl_dir, module, chapter=None):
    matches = [e for e in find_modules(rtl_dir, chapter) if e[1] == module]
    if not matches:
        sys.exit(f"error: no {module}.v found under {rtl_dir}/chapter_*"
                 + (f" matching chapter {chapter}" if chapter else ""))
    if len(matches) > 1:
        chapters = ", ".join(e[0] for e in matches)
        sys.exit(f"error: {module}.v exists in multiple chapters ({chapters}); use -c to choose")
    return matches[0]

# --------------------------------------------------------------- rendering

def decl(width):
    return f"[{width - 1}:0] " if width > 1 else ""


def disp_fmt(width):
    return "%b" if width <= 4 else "%h"


def literal(value, width):
    if width <= 4:
        return f"{width}'b{value:0{width}b}"
    return f"{width}'h{value:0{(width + 3) // 4}x}"


def plain(value, width):
    if width <= 4:
        return f"{value:0{width}b}"
    return f"{value:0{(width + 3) // 4}x}"

def render(module, ports, num_cases):
    ins = [p for p in ports if p.direction == "input"]
    outs = [p for p in ports if p.direction == "output"]
    T = "    " # 4-space tab expansion instead of tabs
    L = []
    add = L.append

    add("`timescale 1ns / 1ps")
    add("")
    add(f"module test_{module};")
    add(f"{T}// test signals")
    for p in ins:
        add(f"{T}reg {decl(p.width)}test_{p.name};")
    for p in outs:
        add(f"{T}wire {decl(p.width)}test_{p.name};")
    add(f"{T}reg error_occurred = 0;")
    add("")
    add(f"{T}// instantiate the device under test and wire it to the bench signals")
    add(f"{T}{module} dut (")
    conns = [f"{T}{T}.{p.name}(test_{p.name})" for p in ports]
    add(",\n".join(conns))
    add(f"{T});")
    add("")

    # reusable task
    add(f"{T}// reusable task for each test case")
    add(f"{T}task check_case;")
    for p in ins:
        add(f"{T}{T}input {decl(p.width)}{p.name}_val;")
    for p in outs:
        add(f"{T}{T}input {decl(p.width)}expected_{p.name};")
    add(f"{T}{T}begin")
    for p in ins:
        add(f"{T}{T}{T}test_{p.name} = {p.name}_val;")
    add(f"{T}{T}{T}#10;")
    add("")
    row_fmt = " | ".join(disp_fmt(p.width) for p in ins + outs)
    row_args = ", ".join(f"test_{p.name}" for p in ins + outs)
    add(f'{T}{T}{T}$display("%0t | {row_fmt}", $time, {row_args});')
    cond = " || ".join(f"test_{p.name} !== expected_{p.name}" for p in outs)
    add(f"{T}{T}{T}if ({cond}) begin")
    fail_fmt = " | ".join(f"{p.name}: {disp_fmt(p.width)}" for p in ins)
    fail_fmt += " | " + " | ".join(
        f"Expected {p.name}: {disp_fmt(p.width)} | Got: {disp_fmt(p.width)}" for p in outs
    )
    fail_args = ", ".join(
        ["$time"]
        + [f"test_{p.name}" for p in ins]
        + [a for p in outs for a in (f"expected_{p.name}", f"test_{p.name}")]
    )
    add(f'{T}{T}{T}{T}$display("[FAIL @ %0t] {fail_fmt}", {fail_args});')
    add(f"{T}{T}{T}{T}error_occurred = 1;")
    add(f"{T}{T}{T}end")
    add(f"{T}{T}end")
    add(f"{T}endtask")
    add("")

    # initial block
    header = "Time | " + " | ".join(p.name for p in ins + outs)
    add(f"{T}// actual code running the tasks to do the test cases")
    add(f"{T}initial begin")
    add(f'{T}{T}$timeformat(-9, 0, " ns", 8);')
    add(f"{T}{T}// Print the header for the results table")
    add(f'{T}{T}$display("{header}");')
    add(f'{T}{T}$display("{"-" * len(header)}");')
    add("")

    nblank_out = ", " * len(outs)  # trailing blanks for expected outputs
    if num_cases is None:
        total = 2 ** sum(p.width for p in ins)
        add(f"{T}{T}// Fill in expected outputs for all {total} input combinations")
        combos = itertools.product(*[range(2 ** p.width) for p in ins])
        for n, combo in enumerate(combos, 1):
            args = ", ".join(literal(v, p.width) for v, p in zip(combo, ins))
            desc = ", ".join(plain(v, p.width) for v, p in zip(combo, ins))
            add(f"{T}{T}check_case({args}{nblank_out}); // Test case {n}: {desc} -> ")
    else:
        add(f"{T}{T}// Fill in inputs and expected outputs for each case")
        blanks = ", ".join([""] * (len(ins) + len(outs)))
        for n in range(1, num_cases + 1):
            add(f"{T}{T}check_case({blanks}); // Test case {n}")
    add("")

    title = module.replace("_", " ").upper()
    add(f"{T}{T}if (error_occurred) begin")
    add(f'{T}{T}{T}$display("--> {title} TEST: FAILED");')
    add(f"{T}{T}{T}$finish(1);")
    add(f"{T}{T}end else begin")
    add(f'{T}{T}{T}$display("--> {title} TEST: PASSED");')
    add(f"{T}{T}{T}$finish(0);")
    add(f"{T}{T}end")
    add(f"{T}end")
    add("endmodule")
    return "\n".join(L) + "\n"

def render_sequential(module, ports, clock, num_cases, pre_edge_check=False):
    """Bench for clock-driven modules: one tick_and_check call per clock cycle."""
    ins = [p for p in ports if p.direction == "input" and p.name != clock]
    outs = [p for p in ports if p.direction == "output"]
    T = "    "
    L = []
    add = L.append

    row_cols = [clock] + [p.name for p in ins + outs]
    row_fmt = " | ".join(["%b"] + [disp_fmt(p.width) for p in ins + outs])
    row_args = ", ".join(f"test_{n}" for n in row_cols)

    def row(indent):
        add(f'{indent}$display("%0t | {row_fmt}", $time, {row_args});')

    def fail_check(indent, label, ref="expected_"):
        cond = " || ".join(f"test_{p.name} !== {ref}{p.name}" for p in outs)
        fmt = f"[FAIL @ %0t] {label}:"
        args = ["$time"]
        if ins:
            fmt += " " + " ".join(f"{p.name}={disp_fmt(p.width)}" for p in ins)
            args += [f"test_{p.name}" for p in ins]
        fmt += " " + " ".join(
            f"{ref}{p.name}={disp_fmt(p.width)} got={disp_fmt(p.width)}" for p in outs
        )
        args += [a for p in outs for a in (f"{ref}{p.name}", f"test_{p.name}")]
        add(f"{indent}if ({cond}) begin")
        add(f'{indent}{T}$display("{fmt}",')
        add(f'{indent}{T}         {", ".join(args)});')
        add(f"{indent}{T}error_occurred = 1;")
        add(f"{indent}end")

    add("`timescale 1ns / 1ps")
    add("")
    add(f"module test_{module};")
    add(f"{T}// test signals")
    add(f"{T}reg test_{clock};")
    for p in ins:
        add(f"{T}reg {decl(p.width)}test_{p.name};")
    for p in outs:
        add(f"{T}wire {decl(p.width)}test_{p.name};")
    add(f"{T}reg error_occurred = 0;")
    if pre_edge_check:
        add(f"{T}// last output values we verified; outputs must not move before the next edge")
        for p in outs:
            add(f"{T}reg {decl(p.width)}prev_{p.name};")
    add("")
    add(f"{T}// instantiate the device under test and wire it to the bench signals")
    add(f"{T}{module} dut (")
    add(",\n".join(f"{T}{T}.{p.name}(test_{p.name})" for p in ports))
    add(f"{T});")
    add("")

    add(f"{T}// one full clock cycle: set up inputs, rising edge, check, perturb, check, fall")
    add(f"{T}task tick_and_check;")
    for p in ins:
        add(f"{T}{T}input {decl(p.width)}{p.name}_val;")
    for p in outs:
        add(f"{T}{T}input {decl(p.width)}expected_{p.name};")
    add(f"{T}{T}begin")
    add(f"{T}{T}{T}// Set up data while clock is low")
    add(f"{T}{T}{T}test_{clock} = 1'b0;")
    for p in ins:
        add(f"{T}{T}{T}test_{p.name} = {p.name}_val;")
    add(f"{T}{T}{T}#5;")
    row(f"{T}{T}{T}")
    if pre_edge_check:
        add(f"{T}{T}{T}// Outputs must still hold the previous state: no edge has happened yet")
        fail_check(f"{T}{T}{T}", "before posedge", ref="prev_")
    add("")
    add(f"{T}{T}{T}// Rising clock edge captures the inputs")
    add(f"{T}{T}{T}test_{clock} = 1'b1;")
    add(f"{T}{T}{T}#1;")
    row(f"{T}{T}{T}")
    fail_check(f"{T}{T}{T}", "after posedge")
    add("")
    add(f"{T}{T}{T}// Mutate inputs while clock is high; outputs must hold")
    add(f"{T}{T}{T}#4;")
    row(f"{T}{T}{T}")
    for p in ins:
        add(f"{T}{T}{T}test_{p.name} = ~{p.name}_val;")
    add(f"{T}{T}{T}#2;")
    row(f"{T}{T}{T}")
    fail_check(f"{T}{T}{T}", "during clk=1 hold")
    add("")
    add(f"{T}{T}{T}// Return clock low")
    add(f"{T}{T}{T}test_{clock} = 1'b0;")
    add(f"{T}{T}{T}#3;")
    row(f"{T}{T}{T}")
    if pre_edge_check:
        add("")
        for p in outs:
            add(f"{T}{T}{T}prev_{p.name} = expected_{p.name};")
    add(f"{T}{T}end")
    add(f"{T}endtask")
    add("")

    header = "Time | " + " | ".join(row_cols)
    add(f"{T}// actual code running the tasks to do the test cases")
    add(f"{T}initial begin")
    add(f"{T}{T}$timeformat(-9, 0, \" ns\", 8);")
    add(f"{T}{T}// Print the header for the results table")
    add(f'{T}{T}$display("{header}");')
    add(f'{T}{T}$display("{"-" * len(header)}");')
    add(f"{T}{T}test_{clock} = 1'b0;")
    for p in ins:
        add(f"{T}{T}test_{p.name} = {p.width}'d0;")
    add(f"{T}{T}#5;")
    row(f"{T}{T}")
    if pre_edge_check:
        add(f"{T}{T}// Whatever the power-up value is (X or 0), treat it as the baseline")
        for p in outs:
            add(f"{T}{T}prev_{p.name} = test_{p.name};")
    add("")

    sig = ", ".join([f"{p.name}" for p in ins] + [f"expected_{p.name}" for p in outs])
    add(f"{T}{T}// Fill in one call per clock cycle: tick_and_check({sig})")
    add(f"{T}{T}// Outputs are X until the first edge, and state carries over between calls.")
    blanks = ", ".join([""] * (len(ins) + len(outs)))
    for n in range(1, num_cases + 1):
        add(f"{T}{T}tick_and_check({blanks}); // Cycle {n}")
    add("")

    title = module.replace("_", " ").upper()
    add(f"{T}{T}if (error_occurred) begin")
    add(f'{T}{T}{T}$display("--> {title} TEST: FAILED");')
    add(f"{T}{T}{T}$finish(1);")
    add(f"{T}{T}end else begin")
    add(f'{T}{T}{T}$display("--> {title} TEST: PASSED");')
    add(f"{T}{T}{T}$finish(0);")
    add(f"{T}{T}end")
    add(f"{T}end")
    add("endmodule")
    return "\n".join(L) + "\n"

# -------------------------------------------------------------------- main

def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("module", nargs="?", help="module name, e.g. and_gate (omit for a pick list)")
    ap.add_argument("-c", "--chapter", metavar="N",
                    help="limit to one chapter (e.g. 2 or chapter_2); mainly useful for the pick list")
    ap.add_argument("-n", "--num-cases", type=int, metavar="N",
                    help="skip the full permutation; emit N fully blank cases (for wide buses)")
    ap.add_argument("-f", "--force", action="store_true", help="overwrite an existing test file")
    ap.add_argument("--rtl-dir", type=Path, default=REPO_ROOT / "rtl")
    ap.add_argument("--test-dir", type=Path, default=REPO_ROOT / "test")
    ap.add_argument("-s", "--sequential", "--clocked", dest="sequential", action="store_true",
                    help="clock-driven module: emit a tick_and_check bench instead of a truth table")
    ap.add_argument("--clock-name", default="clk", metavar="NAME",
                    help="name of the clock input in sequential mode (default: clk)")
    ap.add_argument("--pre-edge-check", action="store_true",
                    help="sequential mode: also assert outputs are unchanged before the clock edge "
                         "(skip for chips with combinational outputs, e.g. RAM reads)")
    args = ap.parse_args(argv)

    if args.num_cases is not None and args.num_cases < 1:
        ap.error("--num-cases must be at least 1")

    if args.module:
        chapter_name, module, src_path = resolve_module(args.rtl_dir, args.module, args.chapter)
    else:
        chapter_name, module, src_path = choose_module(args.rtl_dir, args.test_dir, args.chapter)

    try:
        ports = parse_ports(src_path.read_text(), module)
    except ValueError as e:
        sys.exit(f"error: {src_path.name}: {e}")

    if args.pre_edge_check and not args.sequential:
        ap.error("--pre-edge-check only applies with -s/--sequential")

    if args.sequential:
        clk = next((p for p in ports if p.name == args.clock_name and p.direction == "input"), None)
        if clk is None:
            sys.exit(f"error: {src_path.name} has no input named {args.clock_name!r}; "
                     f"use --clock-name")
        if clk.width != 1:
            sys.exit(f"error: clock {args.clock_name!r} must be 1 bit wide")
        n = args.num_cases or DEFAULT_SEQ_CASES
        text = render_sequential(module, ports, args.clock_name, n, args.pre_edge_check)
    else:
        in_bits = sum(p.width for p in ports if p.direction == "input")
        if args.num_cases is None and in_bits > MAX_EXHAUSTIVE_INPUT_BITS:
            sys.exit(f"error: {in_bits} input bits means {2 ** in_bits} permutations; "
                     f"use -n N to generate N blank cases instead")
        text = render(module, ports, args.num_cases)

    out_path = args.test_dir / chapter_name / f"test_{module}.v"
    if out_path.exists() and not args.force:
        sys.exit(f"error: {out_path} already exists (use --force to overwrite)")

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(text)
    print(f"wrote {out_path.relative_to(REPO_ROOT) if out_path.is_relative_to(REPO_ROOT) else out_path}")
    return 0

# main function to run from command-line input
if __name__ == "__main__":
    sys.exit(main())
