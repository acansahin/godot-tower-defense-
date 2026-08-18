#!/usr/bin/env python3
"""Re-space a sheet whose frames touch, so the row-based cutter can find all of them.

``cut_sprites.py`` splits a cycle on EMPTY SCANLINES, which needs a clear horizontal band
between every pair of frames. A generator asked for 60px of empty rows does not always give
them, and when two frames overlap vertically the cutter silently returns one fewer frame than
was drawn — the Air sheet came back as 11 rows for 12 poses.

Raising ``gap_tol`` is not the fix. It lets a scanline carry a few opaque samples and still
count as background, so it does separate the pair — and it also eats the thin extremities at
the top and bottom of every OTHER frame. Measured on the Air cycle: the tolerance that finally
split frames 11 and 12 also cropped frame 1 from 322px to 267px, shearing the tips off the
raised wings.

The real geometry is that the two creatures do not touch — frame 11's dangling feet and frame
12's rising wingtip merely overlap in Y while sitting apart in X, and no horizontal line can
separate what is diagonally adjacent. But they ARE separate connected regions, so labelling
the sheet by connectivity finds them exactly, and rewriting it one frame per band with a real
gap hands the cutter the sheet it expected. Nothing is cropped and nothing is redrawn.

Usage::

    python tools/respace_frames.py <in.png> <out.png> [--frames N] [--gap N]

``--frames`` is how many poses the sheet should hold; the N largest connected regions are
taken as the frames and every smaller speck (a loose claw tip, a highlight island left by
keying) is merged into whichever frame it lies nearest, so nothing is dropped.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from png_reader import Png, write_rgba  # noqa: E402

ALPHA = 38          # same ink test the rest of the pipeline uses
DEFAULT_GAP = 120


def components(alpha, w, h):
    """Label connected opaque regions, 8-connected so a diagonal hairline stays one piece."""
    label = [0] * (w * h)
    blobs = []
    for start in range(w * h):
        if label[start] or not alpha[start]:
            continue
        n = len(blobs) + 1
        stack = [start]
        label[start] = n
        cells = []
        while stack:
            i = stack.pop()
            cells.append(i)
            y, x = divmod(i, w)
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h:
                        j = ny * w + nx
                        if not label[j] and alpha[j]:
                            label[j] = n
                            stack.append(j)
        blobs.append(cells)
    return blobs


def bbox_of(cells, w):
    xs = [i % w for i in cells]
    ys = [i // w for i in cells]
    return min(xs), min(ys), max(xs), max(ys)


def respace(path_in, path_out, want, gap):
    im = Png(path_in)
    w, h = im.width, im.height
    px = [im.rgba(x, y) for y in range(h) for x in range(w)]
    alpha = [1 if p[3] > ALPHA else 0 for p in px]

    blobs = components(alpha, w, h)
    blobs.sort(key=len, reverse=True)
    print(f"  {os.path.basename(path_in)}: {w}x{h}, {len(blobs)} connected region(s)")
    if len(blobs) < want:
        print(f"  ! only {len(blobs)} regions but {want} frames wanted — nothing to re-space")
        return 1
    frames = blobs[:want]
    strays = blobs[want:]
    boxes = [bbox_of(c, w) for c in frames]
    # Merge specks into the nearest frame by vertical distance to its box, so a loose claw
    # tip travels with the creature it came off rather than becoming a frame of its own.
    for s in strays:
        sy = sum(i // w for i in s) / len(s)
        best = min(range(want), key=lambda k: min(abs(sy - boxes[k][1]), abs(sy - boxes[k][3])))
        frames[best].extend(s)
    if strays:
        print(f"    {len(strays)} speck(s) merged into their nearest frame")

    order = sorted(range(want), key=lambda k: bbox_of(frames[k], w)[1])
    boxes = {k: bbox_of(frames[k], w) for k in order}
    heights = [boxes[k][3] - boxes[k][1] + 1 for k in order]
    out_h = sum(heights) + gap * (want - 1)
    out = bytearray(b"\0\0\0\0" * (w * out_h))
    cursor = 0
    for n, k in enumerate(order, start=1):
        x0, y0, x1, y1 = boxes[k]
        for i in frames[k]:
            sy, sx = divmod(i, w)
            ty = cursor + (sy - y0)
            j = (ty * w + sx) * 4
            out[j:j + 4] = bytes(px[i])
        print(f"    frame {n:>2}: {x1 - x0 + 1}x{y1 - y0 + 1} at source y={y0}..{y1}")
        cursor += heights[n - 1] + gap
    write_rgba(path_out, w, out_h, bytes(out))
    print(f"  -> {path_out}  {w}x{out_h}  ({want} frames, {gap}px gaps)")
    return 0


def main() -> int:
    args = list(sys.argv[1:])
    want, gap = 12, DEFAULT_GAP
    for flag, setter in (("--frames", "want"), ("--gap", "gap")):
        if flag in args:
            i = args.index(flag)
            val = int(args[i + 1])
            if setter == "want":
                want = val
            else:
                gap = val
            del args[i:i + 2]
    if len(args) != 2:
        print(__doc__)
        return 1
    return respace(args[0], args[1], want, gap)


if __name__ == "__main__":
    raise SystemExit(main())
