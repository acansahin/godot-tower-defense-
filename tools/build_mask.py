#!/usr/bin/env python3
"""Find the OPEN GROUND in a board painting and write the mask placement reads.

A tower may stand on grass and nothing else. The board is one painted image, so the trees,
the cliffs and the waterfall are pixels rather than objects — this derives "where is there
actually room to build" from the painting, the same way water_mask.py derives where the
water is, instead of anyone typing circles over a landscape they measured by eye.

`Game.can_build_at()` samples the result, so re-running this after a repaint is the whole
update: no constants to re-measure, no zones to re-place.

Three things make it more than a colour test:

* **Yellow-green is the signal, not "green".** Conifers are green too — very green. What
  separates the sunlit meadow from the canopy is how little BLUE it has: measured off this
  board, grass runs (110-128, 110-129, 22-28), so green sits 90-100 above blue, while a tree
  is (16, 30, 14) and a rock (19, 24, 16), both with green barely 10-20 above blue. So the
  test is `g - b`, with a brightness floor to drop everything in shadow.
* **Per BLOCK, not per pixel.** A lit tree top and a yellow flower both pass a per-pixel
  test. A block counts as open only if a good fraction of it does, which a highlight never
  manages and a meadow always does.
* **A majority filter afterwards.** Without it the mask speckles: single open blocks in the
  middle of forest (a sunlit branch) and single blocked blocks in the middle of a meadow (a
  shadow, a bush). Both are lies about where a 60px-wide tower can stand, and the second
  kind is worse — an invisible hole the player is told "no" over. Each pass replaces a block
  with the majority of its neighbourhood, which closes both.

Water is masked out separately using water_mask.py's own test, so a pond never counts as
open ground however bright it is.

Usage::

    python tools/build_mask.py <board.png> [mask.png]
    python tools/build_mask.py <board.png> --ground=235,240,248 --tol=70
    python tools/build_mask.py <board.png> --ground=... --water=20,130,165 --watertol=90

With no output path it writes `<board>_build.png` beside the board. Point the `build_mask`
field of the board's `Game.BOARDS` row at it — that table is the only thing that has to know
the mask exists, and a board missing the field simply keeps free placement.

**`--ground` is for a board that is not a green meadow.** The default test above is
"is this warm yellow-green", which snow, ash and basalt all answer no to, so an Alaska or
Pompeii board otherwise measures as having nowhere to build at all — and measures it
silently, writing a black mask and reporting 0%. With `--ground` the board says what its
ground looks like and the test becomes distance from that colour; `--tol` (default 100) is
how far a pixel may sit from it. Both want measuring per board — see `near()` for why the
reference is declared rather than detected, and why the tolerance is not one number.

**`--water` is the same switch for the other colour class**, and it is the one an ICE board
needs most. `is_water` reads "bluer than it is red", which identifies water only on a board
whose ground is green. Measured on the first glacier board, 59% of the WHOLE IMAGE passed
it — glacier ice is pale blue — which would have rippled the entire surface and, since water
is excluded from open ground, left almost nowhere to build. The meltwater is separable: its
core reads rgb(0, 120, 160) against ice at rgb(200, 220, 240), about 240 apart.
"""

from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from png_reader import Png, write_rgba  # noqa

BLOCK = 8          # mask pixel = BLOCK x BLOCK of board
GREEN_OVER_BLUE = 35   # how far green must sit above blue for "meadow, not canopy"
BRIGHTNESS = 100       # r+g+b floor; drops everything sitting in shade
FILL = 0.30            # fraction of a block that must be open for the block to count
WATER_FILL = 0.20      # a block with this much water in it is never open ground
MAJORITY = 2           # despeckle passes


def is_water(r: int, g: int, b: int) -> bool:
    """water_mask.py's own test, kept identical on purpose — see its docstring."""
    return b > r + 25 and b > 70 and g > r


def is_open(r: int, g: int, b: int) -> bool:
    return (g - b) > GREEN_OVER_BLUE and (r + g + b) > BRIGHTNESS


def near(ref: tuple[int, int, int], tol: float):
    """`is_open` for a board whose ground is not green grass.

    The test above asks "is this warm yellow-green", which is a question only a temperate
    meadow answers yes to. Measured against the real thing, every snow tone and every ash
    tone fails it: sunlit snow (235, 240, 248) has g-b = -8 and an ash plain (105, 98, 92)
    has g-b = 6, both far under GREEN_OVER_BLUE. An Alaska or Pompeii board therefore
    measures as having NOWHERE to build, and it does so silently -- the tool writes a black
    mask and reports 0% rather than failing.

    So a board that is not green declares what its ground looks like and this asks how far a
    pixel is from that, in plain RGB distance. Everything around it is untouched: per pixel,
    then FILL per block, then the water exclusion, then the majority despeckle.

    WHY DECLARED RATHER THAN DETECTED. The first attempt found the reference automatically,
    as the modal colour among low-contrast blocks. On the S board it nominated (11, 22, 9) --
    the CONIFER FOREST, which is uniform enough at 8px to win the vote. A detector that can
    quietly pick the wrong ground is worse than the green test it replaces, because the green
    test fails loudly (zero open ground) while that one fails plausibly.

    TOLERANCE IS PER BOARD and wants measuring, not guessing. Scored against the three
    shipped masks a tolerance of 100 reproduces them to 85-89% of blocks while losing under
    4% of the ground they allow -- but it is slightly more permissive than the green test, so
    it is NOT a drop-in for the boards already balanced against those masks. It also has to
    be tighter where the ground and the obstacle are close: on ash (105, 98, 92) a basalt
    outcrop (45, 40, 38) sits exactly 100 away, so 100 would let towers stand on the rock.
    """
    t2 = float(tol) * float(tol)
    rr, gg, bb = ref

    def test(r: int, g: int, b: int) -> bool:
        dr, dg, db = r - rr, g - gg, b - bb
        return dr * dr + dg * dg + db * db <= t2

    return test


def majority(grid: list[int], w: int, h: int) -> list[int]:
    """One despeckle pass: a block becomes whatever most of its 3x3 neighbourhood is.

    Ties (exactly half open) keep the block's own value, so a straight shoreline does not
    creep in either direction over repeated passes.
    """
    out = list(grid)
    for y in range(h):
        for x in range(w):
            opens = total = 0
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    sx, sy = x + dx, y + dy
                    if 0 <= sx < w and 0 <= sy < h:
                        opens += grid[sy * w + sx]
                        total += 1
            if opens * 2 > total:
                out[y * w + x] = 1
            elif opens * 2 < total:
                out[y * w + x] = 0
    return out


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    flags = {a.split("=")[0]: a.split("=", 1)[-1] for a in sys.argv[1:] if a.startswith("--")}

    board = os.path.abspath(args[0])
    if len(args) > 1:
        out_path = os.path.abspath(args[1])
    else:
        root, _ = os.path.splitext(board)
        out_path = root + "_build.png"

    # A board whose ground is not green grass declares its ground colour instead; see near().
    open_test = is_open
    water_test = is_water
    label = "green-over-blue"
    if "--ground" in flags:
        ref = tuple(int(v) for v in flags["--ground"].split(","))
        if len(ref) != 3:
            print("--ground wants three numbers, e.g. --ground=235,240,248")
            return 2
        tol = float(flags.get("--tol", 100.0))
        open_test = near(ref, tol)
        label = "near rgb%s tol %.0f" % (str(ref), tol)
    if "--water" in flags:
        wref = tuple(int(v) for v in flags["--water"].split(","))
        if len(wref) != 3:
            print("--water wants three numbers, e.g. --water=20,130,165")
            return 2
        water_test = near(wref, float(flags.get("--watertol", 90.0)))
        label += ", water near rgb%s" % (str(wref),)

    img = Png(board)
    bw, bh = img.width // BLOCK, img.height // BLOCK
    grid = [0] * (bw * bh)
    for by in range(bh):
        for bx in range(bw):
            opens = water = 0
            for y in range(by * BLOCK, (by + 1) * BLOCK):
                for x in range(bx * BLOCK, (bx + 1) * BLOCK):
                    px = img.rgb(x, y)
                    if water_test(*px):
                        water += 1
                    elif open_test(*px):
                        opens += 1
            n = float(BLOCK * BLOCK)
            if water / n >= WATER_FILL:
                continue
            grid[by * bw + bx] = 1 if opens / n >= FILL else 0
    raw_open = sum(grid)

    for _ in range(MAJORITY):
        grid = majority(grid, bw, bh)

    out = bytearray(bw * bh * 4)
    for i, v in enumerate(grid):
        level = 255 if v else 0
        out[i * 4] = out[i * 4 + 1] = out[i * 4 + 2] = level
        out[i * 4 + 3] = 255
    write_rgba(out_path, bw, bh, bytes(out))

    final_open = sum(grid)
    print(f"  board {img.width}x{img.height} -> mask {bw}x{bh} (block {BLOCK}px)")
    print(f"  ground test {label}")
    print(f"  open ground {100.0 * raw_open / len(grid):.1f}% raw"
          f" -> {100.0 * final_open / len(grid):.1f}% after {MAJORITY} majority passes")
    print(f"  wrote {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
