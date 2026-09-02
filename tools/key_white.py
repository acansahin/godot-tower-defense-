#!/usr/bin/env python3
"""Lift a generated sheet off a white background, restoring the alpha it was saved without.

The art pipeline wants transparent PNGs — ``cut_sprites.py`` splits a sheet on its EMPTY
scanlines, and the game draws the sprite straight onto the board. A sheet that arrives
flattened onto white (PNG colour type 2, no alpha channel at all) stops the cutter dead: it
finds one band covering the whole image, and anything that did get through would be drawn as
a white box around the creature.

Re-exporting with alpha from the generator is still the better answer when it is available.
This is for when it is not.

Usage::

    python tools/key_white.py <in.png> <out.png> [--thresh N] [--keep-pockets] [--feather N]

How it works, and why each part is not optional:

* **Connectivity, not a threshold.** The background is flood-filled from the border rather
  than selected by brightness, so a light highlight ON the creature is never mistaken for
  background no matter how pale it is. The threshold only says what the fill may cross.
* **A generous threshold.** These backgrounds are not flat white: measured on the first Air
  sheet, the "white" ranged over 235-255 with compression noise. A tight threshold leaves
  that noise standing as a speckled rim, which is exactly the white halo this is meant to
  avoid. 228 clears the noise while staying far above the creature's own edge, which drops
  to ~135 within a single pixel.
* **A matte solve on the edge.** The anti-aliased boundary is about ONE pixel wide and each
  of those pixels is a genuine blend of creature over white. Left opaque they are a bright
  outline; simply cut away they leave a jagged silhouette. So coverage is solved per pixel
  against the nearest solid neighbour's colour — ``obs = a*F + (1-a)*255`` for ``a`` — and
  the white is divided back out, which is what makes the result composite cleanly onto a
  dark board instead of onto the white it was flattened against.
* **``--feather N`` for art with a GLOW.** The matte above assumes the boundary is one pixel
  wide, which holds for a hard-edged creature and fails for one that radiates: the fire
  avatar's ember rim fades to white over several pixels, and 33% of its silhouette's edge came
  out pale (2% is what the hand-keyed roster measures). Feathering peels that band inward N
  times, solving each pale, near-neutral edge pixel as coverage over white. Saturated pixels
  are never touched, so the ember rim itself survives — it is the WHITE bleeding out of it
  that goes. Off by default, since a hard-edged sheet does not need it.

* **Enclosed pockets.** A gap fully surrounded by the creature — between a wing and the
  body, between the legs — is background the border fill can never reach. Those are removed
  too, unless ``--keep-pockets``. Only regions that are ENTIRELY above the threshold go, so
  this cannot eat a shaded interior.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from png_reader import Png, write_rgba  # noqa: E402

THRESH = 228        # what the flood fill may cross; see the docstring for why not 245
NEUTRAL = 10        # background is grey; this rejects saturated pixels of the same value


def _neutral_bright(rgb, i, thresh):
    r, g, b = rgb[i]
    return min(r, g, b) >= thresh and max(r, g, b) - min(r, g, b) <= NEUTRAL


def _flood_border(rgb, w, h, thresh):
    mask = bytearray(w * h)
    stack = []
    for x in range(w):
        for i in (x, (h - 1) * w + x):
            if not mask[i] and _neutral_bright(rgb, i, thresh):
                mask[i] = 1
                stack.append(i)
    for y in range(h):
        for i in (y * w, y * w + w - 1):
            if not mask[i] and _neutral_bright(rgb, i, thresh):
                mask[i] = 1
                stack.append(i)
    while stack:
        i = stack.pop()
        y, x = divmod(i, w)
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < w and 0 <= ny < h:
                j = ny * w + nx
                if not mask[j] and _neutral_bright(rgb, j, thresh):
                    mask[j] = 1
                    stack.append(j)
    return mask


def _drop_pockets(rgb, mask, w, h, thresh):
    """Remove background trapped inside the silhouette (wing-to-body gaps, between legs)."""
    seen = bytearray(mask)
    dropped = 0
    for start in range(w * h):
        if seen[start] or not _neutral_bright(rgb, start, thresh):
            continue
        blob = [start]
        seen[start] = 1
        head = 0
        while head < len(blob):
            i = blob[head]
            head += 1
            y, x = divmod(i, w)
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if 0 <= nx < w and 0 <= ny < h:
                    j = ny * w + nx
                    if not seen[j] and _neutral_bright(rgb, j, thresh):
                        seen[j] = 1
                        blob.append(j)
        for i in blob:
            mask[i] = 1
        dropped += len(blob)
    return dropped


FEATHER_PALE = 185   # min channel at or above this is mostly white...
FEATHER_SAT = 45     # ...and neutral enough to be bleed rather than the creature's own glow


def _peel(px, w, h, passes):
    """Solve the pale band left around a glowing edge, one ring of pixels per pass."""
    for _ in range(passes):
        touched = []
        for i in range(w * h):
            if px[i][3] < 40:
                continue
            y, x = divmod(i, w)
            open_side = False
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if 0 <= nx < w and 0 <= ny < h and px[ny * w + nx][3] < 40:
                    open_side = True
                    break
            if not open_side:
                continue
            r, g, b, _a = px[i]
            if min(r, g, b) < FEATHER_PALE or max(r, g, b) - min(r, g, b) > FEATHER_SAT:
                continue
            cov = 1.0 - min(r, g, b) / 255.0
            if cov <= 0.02:
                touched.append((i, (0, 0, 0, 0)))
                continue
            solved = tuple(max(0, min(255, int(round((v - 255 * (1 - cov)) / cov))))
                    for v in (r, g, b))
            touched.append((i, solved + (int(round(cov * 255)),)))
        if not touched:
            break
        for i, value in touched:
            px[i] = value


def key(path_in, path_out, thresh=THRESH, keep_pockets=False, feather=0):
    im = Png(path_in)
    w, h = im.width, im.height
    rgb = [im.rgb(x, y) for y in range(h) for x in range(w)]
    mask = _flood_border(rgb, w, h, thresh)
    outside = sum(mask)
    pocket = 0 if keep_pockets else _drop_pockets(rgb, mask, w, h, thresh)
    print(f"  {os.path.basename(path_in)}: {w}x{h}")
    print(f"    background {100 * outside / (w * h):5.1f}%"
          + (f" + {pocket} px of enclosed pockets" if pocket else ""))

    alpha = bytearray(0 if mask[i] else 255 for i in range(w * h))
    edge = set()
    for i in range(w * h):
        if not alpha[i]:
            continue
        y, x = divmod(i, w)
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < w and 0 <= ny < h and alpha[ny * w + nx] == 0:
                edge.add(i)
                break

    px = []
    for i in range(w * h):
        r, g, b = rgb[i]
        a = alpha[i]
        if a and i in edge:
            y, x = divmod(i, w)
            fg = None
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1),
                           (x - 1, y - 1), (x + 1, y + 1), (x - 1, y + 1), (x + 1, y - 1)):
                if 0 <= nx < w and 0 <= ny < h:
                    j = ny * w + nx
                    if alpha[j] and j not in edge:
                        fg = rgb[j]
                        break
            if fg is not None and min(fg) < 250:
                den = 255 - min(fg)
                cov = min(1.0, max(0.0, (255 - min(r, g, b)) / float(den))) if den > 4 else 1.0
                if cov <= 0.03:
                    a = 0
                else:
                    r = max(0, min(255, int(round((r - 255 * (1 - cov)) / cov))))
                    g = max(0, min(255, int(round((g - 255 * (1 - cov)) / cov))))
                    b = max(0, min(255, int(round((b - 255 * (1 - cov)) / cov))))
                    a = int(round(cov * 255))
        px.append((r, g, b, a))
    if feather:
        _peel(px, w, h, feather)
    out = bytearray()
    for value in px:
        out += bytes(value)
    write_rgba(path_out, w, h, bytes(out))
    print(f"    -> {path_out}  ({len(edge)} edge px matted"
          + (f", {feather} feather passes" if feather else "") + ")")


def main() -> int:
    args = list(sys.argv[1:])
    thresh, keep = THRESH, False
    if "--keep-pockets" in args:
        keep = True
        args.remove("--keep-pockets")
    if "--thresh" in args:
        i = args.index("--thresh")
        thresh = int(args[i + 1])
        del args[i:i + 2]
    feather = 0
    if "--feather" in args:
        i = args.index("--feather")
        feather = int(args[i + 1])
        del args[i:i + 2]
    if len(args) != 2:
        print(__doc__)
        return 1
    key(args[0], args[1], thresh, keep, feather)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
