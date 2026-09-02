#!/usr/bin/env python3
"""Build one cycle sheet out of chosen rows from several generated sheets.

The generator would not hold the stride: every sheet came back with one or more CONTACT frames
drawn as a lunge (1.0-1.27x the figure's height, against a roster that steps 0.61-0.94x), while
the rest of each sheet sat inside the band. Rather than re-roll, this picks the in-band rows out
of the sheets already generated and lays them out as one cycle for cut_sprites.

Frames are centred on their BODY centroid, not their bounding box: the rows come from four
separate generations, each of which placed the creature somewhere different on its canvas, and
an un-aligned join shows up in the game as the creature jumping sideways once a stride.
"""
import sys, os
sys.path.insert(0, r"C:\Users\alica\OneDrive\Belgeler\GitHub\godot-tower-defense-\tools")
from png_reader import Png, write_rgba

GAP = 120  # empty rows between frames, comfortably over cut_sprites' 40px band floor


def parse(args):
    """`<sheet.png>:<row>` pairs, in cycle order. Rows are 1-based, top to bottom."""
    picks = []
    for a in args:
        path, _, row = a.rpartition(":")
        if not path or not row.isdigit():
            raise SystemExit("expected <sheet.png>:<row>, got %r" % a)
        picks.append((path, int(row)))
    return picks


if len(sys.argv) < 3:
    print(__doc__)
    print("usage: python tools/compose_cycle.py <out.png> <sheet.png>:<row> [more...]")
    raise SystemExit(1)
OUT = sys.argv[1]
PICKS = parse(sys.argv[2:])

def bands(p):
    out = []; s = None
    for y in range(p.height):
        n = sum(1 for x in range(0, p.width, 3) if p.rgba(x, y)[3] > 40)
        if n > 2 and s is None: s = y
        elif n <= 2 and s is not None:
            if y - s > 20: out.append((s, y - 1))
            s = None
    if s is not None: out.append((s, p.height - 1))
    return out

cache = {}
frames = []
for name, row in PICKS:
    if name not in cache:
        p = Png(name); cache[name] = (p, bands(p))
    p, bs = cache[name]
    y0, y1 = bs[row - 1]
    xs = [x for x in range(p.width) for y in range(y0, y1 + 1, 2) if p.rgba(x, y)[3] > 40]
    x0, x1 = min(xs), max(xs)
    tot = 0; sx = 0
    for y in range(y0, y1 + 1, 2):
        for x in range(x0, x1 + 1, 2):
            if p.rgba(x, y)[3] > 40: tot += 1; sx += x
    cx = sx / max(tot, 1)
    frames.append({"p": p, "y0": y0, "y1": y1, "x0": x0, "x1": x1, "cx": cx})

# Canvas: wide enough for the widest frame either side of the shared centre line.
half_l = max(int(f["cx"] - f["x0"]) for f in frames)
half_r = max(int(f["x1"] - f["cx"]) for f in frames)
W = half_l + half_r + 40
H_each = max(f["y1"] - f["y0"] + 1 for f in frames)
H = len(frames) * (H_each + GAP) + GAP
buf = bytearray(W * H * 4)
centre = half_l + 20
for i, f in enumerate(frames):
    top = GAP + i * (H_each + GAP) + (H_each - (f["y1"] - f["y0"] + 1))
    p = f["p"]
    for y in range(f["y0"], f["y1"] + 1):
        for x in range(f["x0"], f["x1"] + 1):
            r, g, b, a = p.rgba(x, y)
            if a <= 0: continue
            X = centre + int(round(x - f["cx"])); Y = top + (y - f["y0"])
            if 0 <= X < W and 0 <= Y < H:
                j = (Y * W + X) * 4
                buf[j], buf[j+1], buf[j+2], buf[j+3] = r, g, b, a
write_rgba(OUT, W, H, bytes(buf))
print("  composed %d frames -> %s  (%dx%d)" % (len(frames), OUT, W, H))
print("  now cut it as ONE cycle and check the row count:")
print("    python tools/cut_sprites.py %s <out_dir> <name> 220 4" % OUT)
