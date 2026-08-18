#!/usr/bin/env python3
"""Find the water in the board painting and write the mask the flow shader reads.

The board is one painted image, so the lake and the waterfall are pixels rather than
objects. `map.gd`'s shader ripples the water and must leave the grass, the road and the
buildings perfectly still — which needs a mask saying where the water is. This derives that
mask from the painting instead of anyone typing rectangles, so a repaint re-runs the tool
rather than re-measuring by eye.

Two things make it more than a colour test:

* **Blue flowers.** The meadow is scattered with them, and per-pixel they pass any "is this
  teal" rule. So the test is applied per BLOCK: a block counts as water only if a good
  fraction of it is water, which no flower ever manages and every pool does.
* **Soft edges.** A hard mask edge makes the ripple stop dead in a straight line across the
  shore. The block grid is box-blurred, so the motion fades out over the last few pixels of
  water.

Usage::

    python tools/water_mask.py

Writes ``assets/art/board_water.png`` at 1/BLOCK the board's size — a few kilobytes, and
sampled with linear filtering, so the coarseness never shows.
"""

from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from png_reader import Png, write_rgba  # noqa

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), os.pardir,
                    "godottowerdefense", "assets", "art")
BOARD = os.path.join(ROOT, "board_source.png")
OUT = os.path.join(ROOT, "board_water.png")

BLOCK = 8        # mask pixel = BLOCK x BLOCK of board
FILL = 0.35      # fraction of a block that must be water for the block to count
BLUR = 2         # box-blur passes over the block grid


def is_water(r: int, g: int, b: int) -> bool:
    """Teal: blue clearly ahead of red, green between them, and not a shadow.

    Measured off this board — the lake reads about (23, 99, 97) and the falls (63, 85, 93),
    while sunlit grass is (100, 110, 40)-ish and never gets blue above red at all.
    """
    return b > r + 25 and b > 70 and g > r


def main() -> int:
    img = Png(BOARD)
    bw, bh = img.width // BLOCK, img.height // BLOCK
    grid = [0.0] * (bw * bh)
    for by in range(bh):
        for bx in range(bw):
            hits = 0
            for y in range(by * BLOCK, (by + 1) * BLOCK):
                for x in range(bx * BLOCK, (bx + 1) * BLOCK):
                    if is_water(*img.rgb(x, y)):
                        hits += 1
            frac = hits / float(BLOCK * BLOCK)
            grid[by * bw + bx] = 1.0 if frac >= FILL else 0.0
    solid = sum(1 for v in grid if v > 0.0)

    for _ in range(BLUR):
        blurred = [0.0] * (bw * bh)
        for y in range(bh):
            for x in range(bw):
                total = n = 0.0
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        sx, sy = x + dx, y + dy
                        if 0 <= sx < bw and 0 <= sy < bh:
                            total += grid[sy * bw + sx]
                            n += 1.0
                blurred[y * bw + x] = total / n
        grid = blurred

    out = bytearray(bw * bh * 4)
    for i, v in enumerate(grid):
        level = max(0, min(255, int(round(v * 255.0))))
        out[i * 4] = out[i * 4 + 1] = out[i * 4 + 2] = level
        out[i * 4 + 3] = 255
    write_rgba(OUT, bw, bh, bytes(out))
    print(f"  board {img.width}x{img.height} -> mask {bw}x{bh} (block {BLOCK}px)")
    print(f"  {solid} blocks are water = {100.0 * solid / len(grid):.1f}% of the board")
    print(f"  wrote {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
