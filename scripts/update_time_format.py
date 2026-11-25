#!/usr/bin/env python3

"""Bulk-convert old-style generated tests to the $timeformat / %0t time column.

Usage:
    scripts/update_time_format.py                # dry run: show diffs, change nothing
    scripts/update_time_format.py --write        # apply the changes
    scripts/update_time_format.py --row-fmt %8t  # aligned columns instead of %0t
    scripts/update_time_format.py test/chapter_1/test_or_gate.v --write   # specific files

Three edits per file, each skipped if already applied:
  1. row display:   $display("%4t | ...   ->  $display("%0t | ...
  2. initial block: inserts $timeformat(-9, 0, " ns", 8);  as its first statement
  3. fail message:  $display("[FAIL] ...", a, b)  ->  $display("[FAIL @ %0t] ...", $time, a, b)
"""

import argparse
import difflib
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
TIMEFORMAT = '$timeformat(-9, 0, " ns", 8);'

ROW_RE = re.compile(r'(\$display\(")%\d*t(\s*\|)')
FAIL_RE = re.compile(r'\$display\("\[FAIL\]([^"]*)",\s*')
INITIAL_RE = re.compile(r"^([ \t]*)initial\s+begin[ \t]*\n([ \t]*)", re.M)


def convert(text, row_fmt):
    # 1. time column in the per-case row display
    text = ROW_RE.sub(lambda m: f"{m.group(1)}{row_fmt}{m.group(2)}", text)

    # 3. failure message gets a timestamp
    text = FAIL_RE.sub(
        lambda m: f'$display("[FAIL @ {row_fmt}]{m.group(1)}", $time, ', text
    )

    # 2. $timeformat as the first statement of the first initial block
    if "$timeformat" not in text:
        m = INITIAL_RE.search(text)
        if m:
            indent = m.group(2) or (m.group(1) + "    ")
            text = text[: m.start(2)] + indent + TIMEFORMAT + "\n" + text[m.start(2):]
    return text


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("files", nargs="*", type=Path,
                    help="test files to convert (default: test/chapter_*/test_*.v)")
    ap.add_argument("--test-dir", type=Path, default=REPO_ROOT / "test")
    ap.add_argument("--row-fmt", default="%0t", metavar="FMT",
                    help="time format for $display rows (default: %%0t; use %%8t to keep columns aligned)")
    ap.add_argument("-w", "--write", action="store_true",
                    help="apply changes (default is a dry run that prints diffs)")
    args = ap.parse_args(argv)

    files = args.files or sorted(args.test_dir.glob("chapter_*/test_*.v"))
    if not files:
        sys.exit(f"error: no test files found under {args.test_dir}")

    changed = 0
    for path in files:
        old = path.read_text()
        new = convert(old, args.row_fmt)
        if new == old:
            print(f"unchanged  {path}")
        else:
            changed += 1
            print(f"{'updated  ' if args.write else 'would update'}  {path}")
            if not args.write:
                sys.stdout.writelines(difflib.unified_diff(
                    old.splitlines(keepends=True), new.splitlines(keepends=True),
                    fromfile=str(path), tofile=f"{path} (new)", n=1))
            else:
                path.write_text(new)
        if '"[FAIL]' in new:
            print(f"  warning: {path} still has a '[FAIL]' message in a form I didn't recognize")
        if "$timeformat" not in new:
            print(f"  warning: {path} has no initial block, so no $timeformat was added")

    print(f"\n{changed} of {len(files)} file(s) {'updated' if args.write else 'would change'}")
    if changed and not args.write:
        print("dry run only; rerun with --write to apply")
    return 0


if __name__ == "__main__":
    sys.exit(main())
