#!/usr/bin/env python3
"""Cut a row of sprites out of one generated sheet into separate transparent PNGs.

The art for this game is generated a set at a time — five upgrade tiers of one tower in a
single image — because asking for them one at a time gets five towers that do not look
related. This splits such a sheet on its empty columns, trims each sprite to its own alpha
bounding box, and writes them out numbered.

Usage::

    python tools/cut_sprites.py <sheet.png> <out_dir> <prefix>   # e.g. ... towers fire

Each sprite is written as ``<prefix>_<n>.png``, numbered left to right from 1, and the tool
prints the trimmed size and the ground anchor it measured (the horizontal centre of the
bottom row of opaque pixels), which is what the game positions the sprite by.
"""

from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from png_reader import Png, write_rgba  # noqa

ALPHA_FLOOR = 40      # below this a pixel counts as background
MIN_RUN = 40          # ignore specks narrower than this when splitting columns


def columns(img: Png) -> list[tuple[int, int]]:
    runs, start = [], None
    for x in range(img.width):
        used = False
        for y in range(0, img.height, 3):
            if img.rgba(x, y)[3] > ALPHA_FLOOR:
                used = True
                break
        if used and start is None:
            start = x
        elif not used and start is not None:
            if x - start >= MIN_RUN:
                runs.append((start, x))
            start = None
    if start is not None:
        runs.append((start, img.width))
    return runs


def cut(img: Png, x0: int, x1: int):
    """Trim the slice to its opaque bounds and return (w, h, pixels, anchor_x)."""
    top, bottom, left, right = img.height, -1, x1, -1
    for y in range(img.height):
        for x in range(x0, x1):
            if img.rgba(x, y)[3] > ALPHA_FLOOR:
                top = min(top, y)
                bottom = max(bottom, y)
                left = min(left, x)
                right = max(right, x)
    if bottom < 0:
        return None
    w, h = right - left + 1, bottom - top + 1
    out = bytearray(w * h * 4)
    for y in range(h):
        for x in range(w):
            r, g, b, a = img.rgba(left + x, top + y)
            i = (y * w + x) * 4
            out[i], out[i + 1], out[i + 2], out[i + 3] = r, g, b, a
    # Where the sprite meets the ground: the middle of the lowest opaque row.
    ground = [x for x in range(w) if out[((h - 1) * w + x) * 4 + 3] > ALPHA_FLOOR]
    anchor = (ground[0] + ground[-1]) // 2 if ground else w // 2
    return w, h, bytes(out), anchor


def main() -> int:
    if len(sys.argv) < 4:
        print(__doc__)
        return 1
    sheet, out_dir, prefix = sys.argv[1], sys.argv[2], sys.argv[3]
    img = Png(sheet)
    os.makedirs(out_dir, exist_ok=True)
    runs = columns(img)
    print(f"  {os.path.basename(sheet)}: {img.width}x{img.height}, {len(runs)} sprites")
    for i, (x0, x1) in enumerate(runs, start=1):
        piece = cut(img, x0, x1)
        if piece is None:
            continue
        w, h, pixels, anchor = piece
        path = os.path.join(out_dir, f"{prefix}_{i}.png")
        write_rgba(path, w, h, pixels)
        print(f"    {prefix}_{i}.png  {w}x{h}  ground anchor x={anchor}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
