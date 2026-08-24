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

With no output path it writes `<board>_build.png` beside the board, which is where
`Game.build_mask_for()` looks for it.
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
    board = os.path.abspath(sys.argv[1])
    if len(sys.argv) > 2:
        out_path = os.path.abspath(sys.argv[2])
    else:
        root, _ = os.path.splitext(board)
        out_path = root + "_build.png"

    img = Png(board)
    bw, bh = img.width // BLOCK, img.height // BLOCK
    grid = [0] * (bw * bh)
    for by in range(bh):
        for bx in range(bw):
            opens = water = 0
            for y in range(by * BLOCK, (by + 1) * BLOCK):
                for x in range(bx * BLOCK, (bx + 1) * BLOCK):
                    px = img.rgb(x, y)
                    if is_water(*px):
                        water += 1
                    elif is_open(*px):
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
    print(f"  open ground {100.0 * raw_open / len(grid):.1f}% raw"
          f" -> {100.0 * final_open / len(grid):.1f}% after {MAJORITY} majority passes")
    print(f"  wrote {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
