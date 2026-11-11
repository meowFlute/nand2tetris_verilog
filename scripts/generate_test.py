#!/usr/bin/env python3
"""Generate a Verilog test harness skeleton for a module in rtl/.

Usage:
    scripts/generate_test.py and_gate          # full truth table, blank expected values
    scripts/generate_test.py                   # pick list built from rtl/ and test/
    scripts/generate_test.py alu -n 20         # 20 fully blank cases (for wide buses)

The generated file goes to test/test_<module>.v. Expected values (and, in
sampled mode, the inputs too) are left blank so the file won't compile until
you fill them in.
"""

import argparse
import itertools
import re
import sys
from dataclasses import dataclass
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
MAX_EXHAUSTIVE_INPUT_BITS = 10  # 1024 cases; beyond this, require -n


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

def list_modules(rtl_dir):
    return sorted(p.stem for p in rtl_dir.glob("*.v"))


def choose_module(rtl_dir, test_dir):
    names = list_modules(rtl_dir)
    if not names:
        sys.exit(f"error: no .v files found in {rtl_dir}")
    if not sys.stdin.isatty():
        sys.exit("error: no module given and stdin is not interactive")

    print("Modules in rtl/:")
    for i, name in enumerate(names, 1):
        status = "test exists" if (test_dir / f"test_{name}.v").exists() else "no test yet"
        print(f"  {i:2d}) {name:<24} [{status}]")
    choice = input("Pick a number or name: ").strip()

    if choice.isdigit() and 1 <= int(choice) <= len(names):
        return names[int(choice) - 1]
    if choice in names:
        return choice
    sys.exit(f"error: invalid selection {choice!r}")


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
    add(f'{T}{T}{T}$display("%4t | {row_fmt}", $time, {row_args});')
    cond = " || ".join(f"test_{p.name} !== expected_{p.name}" for p in outs)
    add(f"{T}{T}{T}if ({cond}) begin")
    fail_fmt = " | ".join(f"{p.name}: {disp_fmt(p.width)}" for p in ins)
    fail_fmt += " | " + " | ".join(
        f"Expected {p.name}: {disp_fmt(p.width)} | Got: {disp_fmt(p.width)}" for p in outs
    )
    fail_args = ", ".join(
        [f"test_{p.name}" for p in ins]
        + [a for p in outs for a in (f"expected_{p.name}", f"test_{p.name}")]
    )
    add(f'{T}{T}{T}{T}$display("[FAIL] {fail_fmt}", {fail_args});')
    add(f"{T}{T}{T}{T}error_occurred = 1;")
    add(f"{T}{T}{T}end")
    add(f"{T}{T}end")
    add(f"{T}endtask")
    add("")

    # initial block
    header = "Time | " + " | ".join(p.name for p in ins + outs)
    add(f"{T}// actual code running the tasks to do the test cases")
    add(f"{T}initial begin")
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


# -------------------------------------------------------------------- main

def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("module", nargs="?", help="module name, e.g. and_gate (omit for a pick list)")
    ap.add_argument("-n", "--num-cases", type=int, metavar="N",
                    help="skip the full permutation; emit N fully blank cases (for wide buses)")
    ap.add_argument("-f", "--force", action="store_true", help="overwrite an existing test file")
    ap.add_argument("--rtl-dir", type=Path, default=REPO_ROOT / "rtl")
    ap.add_argument("--test-dir", type=Path, default=REPO_ROOT / "test")
    args = ap.parse_args(argv)

    if args.num_cases is not None and args.num_cases < 1:
        ap.error("--num-cases must be at least 1")

    module = args.module or choose_module(args.rtl_dir, args.test_dir)
    src_path = args.rtl_dir / f"{module}.v"
    if not src_path.exists():
        sys.exit(f"error: {src_path} not found")

    try:
        ports = parse_ports(src_path.read_text(), module)
    except ValueError as e:
        sys.exit(f"error: {src_path.name}: {e}")

    in_bits = sum(p.width for p in ports if p.direction == "input")
    if args.num_cases is None and in_bits > MAX_EXHAUSTIVE_INPUT_BITS:
        sys.exit(f"error: {in_bits} input bits means {2 ** in_bits} permutations; "
                 f"use -n N to generate N blank cases instead")

    out_path = args.test_dir / f"test_{module}.v"
    if out_path.exists() and not args.force:
        sys.exit(f"error: {out_path} already exists (use --force to overwrite)")

    args.test_dir.mkdir(parents=True, exist_ok=True)
    out_path.write_text(render(module, ports, args.num_cases))
    print(f"wrote {out_path.relative_to(REPO_ROOT) if out_path.is_relative_to(REPO_ROOT) else out_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
