#!/usr/bin/env python3
"""Stack several generated sheets into one, so a cycle split across files cuts as one cycle.

Twelve frames in a single column is a 1:6 canvas and some generators refuse it, so a long
cycle arrives as two sheets of six. Those cannot simply be cut one after the other:
``cut_sprites.py`` computes ONE shared window per sheet — the union of that sheet's frame
widths and its tallest frame, with every frame bottom-aligned inside it — and hands the whole
cycle to the game at one anchor and one scale. Run twice, the two halves get two different
windows, and the creature changes size and jumps sideways halfway through its beat, which is
the exact defect the shared window exists to prevent.

Stitching first is the cheap fix: concatenate the halves into one tall image, and the existing
cutter's window spans all twelve frames with no change to a tool that is already correct.

Usage::

    python tools/stitch_sheets.py <out.png> <sheet_a.png> <sheet_b.png> [more...] [--gap N]

Sheets are stacked TOP TO BOTTOM in the order given, so pass frames 1-6 before 7-12.

Two things this deliberately does NOT do:

* It does not re-centre anything. Sheets of different widths are padded on the RIGHT to the
  widest, because the creature's horizontal position inside its row is signal — the cutter's
  shared window is built from it, and centring each half separately would shift one half
  against the other and put the jump back.
* It does not trim. Blank margins are left alone; the cutter finds the frames on empty
  scanlines and `--gap` only guarantees the halves do not weld into one band.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from png_reader import Png, write_rgba  # noqa: E402

DEFAULT_GAP = 120  # comfortably over the cutter's 40px "drop this band" floor


def stitch(paths: list[str], gap: int) -> tuple[int, int, bytes]:
    sheets = [Png(p) for p in paths]
    for p, s in zip(paths, sheets):
        print(f"  {os.path.basename(p)}: {s.width}x{s.height}")
    width = max(s.width for s in sheets)
    height = sum(s.height for s in sheets) + gap * (len(sheets) - 1)
    if len({s.width for s in sheets}) > 1:
        print(f"  ! widths differ; padding to {width} on the right (never re-centring)")
    row = bytearray(b"\0\0\0\0" * width)
    out = bytearray()
    y_written = 0
    for n, s in enumerate(sheets):
        if n:
            out += row * gap
            y_written += gap
        for y in range(s.height):
            line = bytearray()
            for x in range(s.width):
                line += bytes(s.rgba(x, y))
            line += b"\0\0\0\0" * (width - s.width)
            out += line
        y_written += s.height
    assert y_written == height, (y_written, height)
    return width, height, bytes(out)


def main() -> int:
    args = [a for a in sys.argv[1:]]
    gap = DEFAULT_GAP
    if "--gap" in args:
        i = args.index("--gap")
        gap = int(args[i + 1])
        del args[i:i + 2]
    if len(args) < 3:
        print(__doc__)
        return 1
    out_path, paths = args[0], args[1:]
    for p in paths:
        if not os.path.exists(p):
            print(f"  ! missing: {p}")
            return 1
    width, height, pixels = stitch(paths, gap)
    write_rgba(out_path, width, height, pixels)
    print(f"  -> {out_path}  {width}x{height}  ({len(paths)} sheets, {gap}px gap)")
    print("  now cut it as ONE cycle, and check the row count it prints:")
    print(f"    python tools/cut_sprites.py {out_path} "
          f"godottowerdefense/assets/art/enemies <name> 150 4")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
