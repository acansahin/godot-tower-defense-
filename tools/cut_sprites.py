#!/usr/bin/env python3
"""Cut a row of sprites out of one generated sheet into separate transparent PNGs.

The art for this game is generated a set at a time — five upgrade tiers of one tower in a
single image — because asking for them one at a time gets five towers that do not look
related. This splits such a sheet on its empty columns, trims each sprite to its own alpha
bounding box, and writes them out numbered.

Usage::

    python tools/cut_sprites.py <sheet.png> <out_dir> <prefix> [max_height]
    python tools/cut_sprites.py <sheet.png> <out_dir> <name,name,...> [max_height]

With a PREFIX, sprites are written ``<prefix>_<n>.png`` numbered left to right from 1, and
each tier is capped a little taller than the last — which is what a tower upgrade ladder
wants.

With a COMMA-SEPARATED NAME LIST, each column is written under its own name and every
sprite gets the same height cap. Rows are detected too: a sheet with one row writes
``<name>.png``, and a sheet with several writes ``<name>_1.png``, ``<name>_2.png``, … one
per row. That is how a walk cycle arrives — the same creature painted twice, opposite legs
forward — and naming the columns here is what stops a five-creature sheet from being
renamed by hand into the wrong archetypes afterwards.

The tool prints the trimmed size and the ground anchor it measured (the horizontal centre
of the bottom row of opaque pixels), which is what the game positions the sprite by.
"""

from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from png_reader import Png, write_rgba  # noqa

ALPHA_FLOOR = 40      # below this a pixel counts as background
MIN_RUN = 40          # ignore specks narrower than this when splitting columns


def columns(img: Png, y0: int = 0, y1: int = -1, gap_tol: int = 0) -> list[tuple[int, int]]:
    """Column runs holding a sprite each.

    `gap_tol` is how many opaque samples a column may still contain and count as background.
    Zero — a column must be completely empty — is right for a sheet whose subjects keep to
    themselves, and wrong for one where a wingspan reaches over the gap into its neighbour:
    there the split points carry a dozen pixels of wing tip and every subject after the
    first merges into one enormous sprite.
    """
    if y1 < 0:
        y1 = img.height
    runs, start = [], None
    for x in range(img.width):
        ink = 0
        for y in range(y0, y1, 3):
            if img.rgba(x, y)[3] > ALPHA_FLOOR:
                ink += 1
        used = ink > gap_tol
        if used and start is None:
            start = x
        elif not used and start is not None:
            if x - start >= MIN_RUN:
                runs.append((start, x))
            start = None
    if start is not None:
        runs.append((start, img.width))
    return runs


def rows(img: Png) -> list[tuple[int, int]]:
    """Bands of non-empty scanlines, so a multi-row sheet splits into one row per pose."""
    runs, start = [], None
    for y in range(img.height):
        used = False
        for x in range(0, img.width, 3):
            if img.rgba(x, y)[3] > ALPHA_FLOOR:
                used = True
                break
        if used and start is None:
            start = y
        elif not used and start is not None:
            if y - start >= MIN_RUN:
                runs.append((start, y))
            start = None
    if start is not None:
        runs.append((start, img.height))
    return runs


def cut(img: Png, x0: int, x1: int, y0: int = 0, y1: int = -1):
    """Trim the slice to its opaque bounds and return (w, h, pixels, anchor_x)."""
    if y1 < 0:
        y1 = img.height
    top, bottom, left, right = y1, -1, x1, -1
    for y in range(y0, y1):
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


def box_downscale(w, h, pixels, target_h):
    """Average-filter the sprite down to `target_h`, keeping the aspect.

    Generated art arrives far bigger than it is drawn — the fire set carries four to seven
    source pixels for every screen pixel — and letting the GPU do that reduction each frame
    either aliases (no mipmaps) or blurs (with them). Doing it ONCE here, with every source
    pixel actually averaged in, is sharper than both, and it takes the files down with it.

    Premultiplying by alpha matters: averaging colour across a transparent edge without it
    drags the background colour of the transparent pixels into the fringe.
    """
    if h <= target_h:
        return w, h, pixels
    scale = target_h / float(h)
    tw, th = max(1, int(round(w * scale))), int(target_h)
    out = bytearray(tw * th * 4)
    for y in range(th):
        y0, y1 = int(y * h / th), max(int((y + 1) * h / th), int(y * h / th) + 1)
        for x in range(tw):
            x0, x1 = int(x * w / tw), max(int((x + 1) * w / tw), int(x * w / tw) + 1)
            r = g = b = a = 0.0
            n = 0
            for sy in range(y0, y1):
                for sx in range(x0, x1):
                    i = (sy * w + sx) * 4
                    pa = pixels[i + 3] / 255.0
                    r += pixels[i] * pa
                    g += pixels[i + 1] * pa
                    b += pixels[i + 2] * pa
                    a += pixels[i + 3]
                    n += 1
            i = (y * tw + x) * 4
            alpha = a / n
            weight = (a / 255.0) or 1.0
            out[i] = min(255, int(r / weight))
            out[i + 1] = min(255, int(g / weight))
            out[i + 2] = min(255, int(b / weight))
            out[i + 3] = int(alpha)
    return tw, th, bytes(out)


def main() -> int:
    if len(sys.argv) < 4:
        print(__doc__)
        return 1
    sheet, out_dir, prefix = sys.argv[1], sys.argv[2], sys.argv[3]
    max_height = int(sys.argv[4]) if len(sys.argv) > 4 else 0
    gap_tol = int(sys.argv[5]) if len(sys.argv) > 5 else 0
    names = [n for n in prefix.split(",") if n] if "," in prefix else []
    img = Png(sheet)
    os.makedirs(out_dir, exist_ok=True)
    bands = rows(img) if names else [(0, img.height)]
    print(f"  {os.path.basename(sheet)}: {img.width}x{img.height}, {len(bands)} row(s)")
    # Cut everything first, then scale, because the cap for a column depends on its TALLEST
    # pose — see below.
    pieces: dict = {}
    for r, (y0, y1) in enumerate(bands, start=1):
        runs = columns(img, y0, y1, gap_tol)
        if names and len(runs) != len(names):
            print(f"    ! row {r} has {len(runs)} sprites but {len(names)} names were given")
        for i, (x0, x1) in enumerate(runs, start=1):
            piece = cut(img, x0, x1, y0, y1)
            if piece is not None:
                pieces[(r, i)] = piece
    # Every pose of ONE creature must come out at ONE scale. Their trimmed boxes differ —
    # an extended leg makes a pose taller — so capping each to the same pixel height would
    # shrink the taller pose back down, and the creature would visibly pulse with every
    # step. Scaling a column by its own tallest pose keeps the difference, which is the
    # bob of the walk itself.
    tallest: dict = {}
    for (r, i), (w, h, _px, _a) in pieces.items():
        tallest[i] = max(tallest.get(i, 0), h)
    for (r, i) in sorted(pieces):
        w, h, pixels, anchor = pieces[(r, i)]
        before = f"{w}x{h}"
        if max_height:
            # A named sheet is a cast of separate creatures, each drawn at its own size by
            # the game, so one flat cap per column. A prefixed one is an upgrade ladder,
            # where each tier is drawn bigger than the last, so the cap grows with it.
            cap = max_height * (h / float(tallest[i])) if names else max_height * (0.8 + 0.1 * i)
            w, h, pixels = box_downscale(w, h, pixels, cap)
        if names:
            stem = names[i - 1] if i <= len(names) else f"extra{i}"
            if len(bands) > 1:
                stem = f"{stem}_{r}"
        else:
            stem = f"{prefix}_{i}"
        write_rgba(os.path.join(out_dir, f"{stem}.png"), w, h, pixels)
        print(f"    {stem}.png  {before} -> {w}x{h}  ground anchor x={anchor}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
