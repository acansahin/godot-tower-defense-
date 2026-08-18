#!/usr/bin/env python3
"""Cut a row of sprites out of one generated sheet into separate transparent PNGs.

The art for this game is generated a set at a time — five upgrade tiers of one tower in a
single image — because asking for them one at a time gets five towers that do not look
related. This splits such a sheet on its empty columns, trims each sprite to its own alpha
bounding box, and writes them out numbered.

Usage::

    python tools/cut_sprites.py <sheet.png> <out_dir> <prefix> [max_height] [gap_tol]
    python tools/cut_sprites.py <sheet.png> <out_dir> <name,name,...> [max_height] [gap_tol]

With a PREFIX, sprites are written ``<prefix>_<n>.png`` numbered left to right from 1, and
each tier is capped a little taller than the last — which is what a tower upgrade ladder
wants.

With a COMMA-SEPARATED NAME LIST, each column is written under its own name and every
sprite gets the same height cap. Rows are detected too: a sheet with one row writes
``<name>.png``, and a sheet with several writes ``<name>_1.png``, ``<name>_2.png``, … one
per row. That is how a walk cycle arrives — the same creature painted once per frame — and
naming the columns here is what stops a five-creature sheet from being renamed by hand into
the wrong archetypes afterwards. A cycle may be any length: the game reads how many frames
exist off the folder. A SINGLE name on a multi-row sheet counts as a name list of one, so one
creature's whole cycle can be generated on a sheet of its own.

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


def rows(img: Png, gap_tol: int = 0) -> list[tuple[int, int]]:
    """Bands of non-empty scanlines, so a multi-row sheet splits into one row per pose.

    `gap_tol` is the same allowance `columns` takes, in the other axis: how many opaque
    samples a scanline may still carry and count as background. A run cycle is the case that
    needs it — the frames are the same creature at slightly different heights, and a raised
    axe or a trailing boot crosses into the gap by a few pixels. At zero tolerance the two
    frames either side of that come out as one 690px sprite.
    """
    runs, start = [], None
    for y in range(img.height):
        ink = 0
        for x in range(0, img.width, 3):
            if img.rgba(x, y)[3] > ALPHA_FLOOR:
                ink += 1
        used = ink > gap_tol
        if used and start is None:
            start = y
        elif not used and start is not None:
            if y - start >= MIN_RUN:
                runs.append((start, y))
            start = None
    if start is not None:
        runs.append((start, img.height))
    return runs


def bbox(img: Png, x0: int, x1: int, y0: int = 0, y1: int = -1):
    """The opaque bounds of a slice as (left, top, right, bottom), or None if it is empty."""
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
    return None if bottom < 0 else (left, top, right, bottom)


def cut(img: Png, x0: int, x1: int, y0: int = 0, y1: int = -1, box=None):
    """Copy a slice out and return (w, h, pixels, anchor_x).

    Trimmed to its own opaque bounds by default. Pass `box` — an explicit
    (left, top, right, bottom) in sheet coordinates — to take a FIXED window instead, which
    is what an animation cycle needs: see `shared_boxes`.
    """
    if y1 < 0:
        y1 = img.height
    found = box if box is not None else bbox(img, x0, x1, y0, y1)
    if found is None:
        return None
    left, top, right, bottom = found
    w, h = right - left + 1, bottom - top + 1
    out = bytearray(w * h * 4)
    for y in range(h):
        sy = top + y
        for x in range(w):
            sx = left + x
            if 0 <= sx < img.width and 0 <= sy < img.height:
                r, g, b, a = img.rgba(sx, sy)
            else:
                r = g = b = a = 0  # a shared box may reach past the sheet; that part is empty
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


def shared_boxes(found: dict) -> dict:
    """One window per creature, big enough for every frame of its cycle.

    Cutting each frame to its OWN alpha bounds is right for a cast of separate creatures and
    wrong for an animation, because the frames of a run do not have the same bounds — a
    trailing leg reaches back and down, an axe swings forward. Trimmed independently, each
    frame is then hung in the game by ITS OWN ground anchor and drawn at ITS OWN scale, and
    the creature jumps forward and swells the moment that leg extends. The measured spread on
    the first six-frame goblin was an anchor 89% of the way to the right on one frame against
    45% on another, and a 26% range in height.

    So a cycle is cut on one window instead: the union of the frames' widths, the tallest
    frame's height, and each frame BOTTOM-ALIGNED inside it — the lowest pixel is the foot on
    the ground, which is the one thing every frame of a run has in common. Every file comes
    out the same size, so one anchor and one scale serve the whole cycle, and what still
    differs between them — the lean, the reach, the rise of the body — is the animation.
    """
    out: dict = {}
    for i in {col for _r, col in found}:
        frames = {r: b for (r, col), b in found.items() if col == i}
        left = min(b[0] for b in frames.values())
        right = max(b[2] for b in frames.values())
        height = max(b[3] - b[1] + 1 for b in frames.values())
        for r, b in frames.items():
            out[(r, i)] = (left, b[3] - height + 1, right, b[3])
    return out


def main() -> int:
    if len(sys.argv) < 4:
        print(__doc__)
        return 1
    sheet, out_dir, prefix = sys.argv[1], sys.argv[2], sys.argv[3]
    max_height = int(sys.argv[4]) if len(sys.argv) > 4 else 0
    gap_tol = int(sys.argv[5]) if len(sys.argv) > 5 else 0
    img = Png(sheet)
    os.makedirs(out_dir, exist_ok=True)
    # A PREFIX is an upgrade ladder and is always one row of tiers; a NAME LIST is a cast and
    # may be stacked into a row per pose. So a lone name on a multi-row sheet is a name, not a
    # prefix — which is what lets ONE creature's whole cycle be generated on its own sheet
    # (the reliable way to get six frames that still look like the same creature) without
    # writing `normal,` with a trailing comma to force it.
    names = [n for n in prefix.split(",") if n] if "," in prefix else []
    if not names and len(rows(img, gap_tol)) > 1:
        names = [prefix]
    bands = rows(img, gap_tol) if names else [(0, img.height)]
    print(f"  {os.path.basename(sheet)}: {img.width}x{img.height}, {len(bands)} row(s)")
    # Find every frame's own bounds first, then decide on ONE window per creature, then cut.
    # The window is the point of the whole pass — see shared_boxes.
    found: dict = {}
    for r, (y0, y1) in enumerate(bands, start=1):
        runs = columns(img, y0, y1, gap_tol)
        if names and len(runs) != len(names):
            print(f"    ! row {r} has {len(runs)} sprites but {len(names)} names were given")
        for i, (x0, x1) in enumerate(runs, start=1):
            b = bbox(img, x0, x1, y0, y1)
            if b is not None:
                found[(r, i)] = b
    boxes = shared_boxes(found) if len(bands) > 1 else None
    pieces: dict = {}
    for key, b in found.items():
        piece = cut(img, 0, img.width, 0, img.height,
                    box=boxes[key] if boxes is not None else b)
        if piece is not None:
            pieces[key] = piece
    # Scale every frame of ONE creature by the same number. With a shared window they are all
    # the same size already, so this just applies the cap; on a single-row sheet (a tower tier
    # ladder, or a cast of separate creatures) the boxes really do differ and scaling by the
    # tallest is what keeps a pair of poses from pulsing.
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
