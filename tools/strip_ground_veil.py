#!/usr/bin/env python3
"""Strip the ground veil a generated elemental sheet paints under its feet — without
shaving the feet off the frames where the legs are simply together.

The first rule here was "if the lowest row is ONE connected run, it bridges the feet, so peel
it". That is true of a water avatar's spray and false of every passing pose in the cycle, where
the two feet really do meet: it peeled up to twelve rows off exactly those frames, left the
calves as the lowest ink, and the cut frames then measured a 1.31x stride where the sheet had
drawn 0.34x.

So the test is WIDTH, not connectivity. A veil spreads wider than the creature's own legs; feet
that touch are narrower than the shins above them. Peel a row only while it is at least
VEIL_RATIO times as wide as the ink a probe-height higher, and never more than MAX_ROWS.
"""
import sys, os
sys.path.insert(0, r"C:\Users\alica\OneDrive\Belgeler\GitHub\godot-tower-defense-\tools")
from png_reader import Png, write_rgba

VEIL_RATIO = 1.45
PROBE = 14      # rows above the row under test, well clear of the ankle
MAX_ROWS = 8

def main(src, dst):
    p = Png(src); W, H = p.width, p.height
    px = [list(p.rgba(x, y)) for y in range(H) for x in range(W)]
    def rowink(y): return any(px[y*W+x][3] > 40 for x in range(0, W, 3))
    bands = []; s = None
    for y in range(H):
        if rowink(y) and s is None: s = y
        elif not rowink(y) and s is not None:
            if y - s > 20: bands.append((s, y - 1))
            s = None
    if s is not None: bands.append((s, H - 1))

    def width(y):
        xs = [x for x in range(W) if px[y*W+x][3] > 40]
        return (max(xs) - min(xs) + 1) if xs else 0

    cleared = []
    for (y0, y1) in bands:
        n = 0
        while n < MAX_ROWS:
            y = y1 - n
            above = y - PROBE
            if above <= y0: break
            w, wa = width(y), width(above)
            if wa <= 0 or w < wa * VEIL_RATIO: break
            for x in range(W): px[y*W+x] = [0, 0, 0, 0]
            n += 1
        cleared.append(n)
    buf = bytearray()
    for c in px: buf += bytes(c)
    write_rgba(dst, W, H, bytes(buf))
    print("  %s -> %s  veil rows removed %s" % (os.path.basename(src), os.path.basename(dst), cleared))

if len(sys.argv) != 3:
    print(__doc__)
    print("usage: python tools/strip_ground_veil.py <keyed.png> <out.png>")
    raise SystemExit(1)
main(sys.argv[1], sys.argv[2])
