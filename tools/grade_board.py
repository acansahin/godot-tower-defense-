#!/usr/bin/env python3
"""Pull a board's open ground into the register the tower roster was painted for.

The roster is lit for `board_source.png` and cannot be repainted cheaply - seventeen sets of
five sprites - so when a new board lands slightly off in value or hue, the cheap end of the
fix is to move the BOARD. This does that with numbers instead of an eye: it measures the
open-ground mean of a reference board, measures the same on the target, and shifts the
target's grass onto it.

Three things make it more than a colour slider:

* **It grades the GRASS, not the picture.** The weight is green-over-blue, the same signal
  `build_mask.py` uses to decide what open ground is - so exactly the pixels that rule calls
  buildable are the pixels that move, and the road, the conifers, the cliffs and the water
  keep the colours the other three readers depend on. Softening the weight over a ramp
  rather than thresholding it avoids a visible seam at the meadow's edge.

* **It is an ADDITIVE shift, so texture survives.** Scaling or gamma would flatten the
  grass's variation along with its mean; adding a constant moves the mean and leaves every
  blade's relationship to its neighbours exactly as painted.

* **It CALIBRATES.** Because the weight is soft, a nominal shift lands short - the first
  pass on `winding_forest_cleared_v7` asked for +26 blue and delivered +22. So it renders,
  measures what actually arrived, corrects the shift by the ratio and renders again. Two
  passes put all three channels within half a unit of target.

`--smooth S` (0..1) is the other half, and it answers a different complaint: a generated
meadow often carries a dense leaf or clover stipple that measures as DETAIL and reads as
NOISE once the board is drawn at 0.766 of its painted size. It competes with the towers
standing on it, which is the opposite of what ground should do. The blur runs on the same
grass weight, so the road, the conifers and the cliffs keep every pixel of their sharpness.
Measure the result the way the eye sees it - detail AFTER downscaling to 1280 - because at
native size a busier board always wins and that is not the question being asked.

What neither can do is the camera. A board painted straight down stays painted straight
down; `art_match.py` reports that separately and no pixel work touches it.

Usage::

    python tools/grade_board.py <board.png> [out.png] [--against <ref.png>] [--smooth S]

Default reference is `board_source.png`, the board the roster was generated against, and
default output is `<board>_graded.png`. Check the result with `art_match.py`, which is where
the targets came from, then rebuild the masks - the grade moves pixels across
`build_mask.py`'s threshold, so `<board>_build.png` must be regenerated from the GRADED file.
"""

from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from build_mask import is_open, is_water  # noqa: E402  the same test, on purpose
from png_reader import Png, write_rgba  # noqa: E402

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(HERE, "godottowerdefense", "assets", "art")
## The board the six element sets were generated against, so its open ground is what the
## masonry is lit for. See docs/board-art-prompt.md.
DEFAULT_REFERENCE = os.path.join(ART, "board_source.png")

## Green-over-blue below which a pixel is left alone, and the ramp over which it comes fully
## under the grade. `build_mask.py` calls open ground `(g - b) > 35`; starting the ramp below
## that and finishing above it means the pixels that rule cares about are fully graded while
## the canopy (g - b around 15) is untouched, with no hard edge in between.
WEIGHT_FLOOR = 20.0
WEIGHT_RAMP = 60.0
## Renders needed to land on target. The first measures, the second corrects. A third moves
## nothing - measured at under 0.2 per channel.
PASSES = 2
## Sampling stride when measuring a mean. Every other pixel in both axes is a quarter of the
## work and agrees with a full scan to under 0.1 per channel.
SAMPLE = 2


def open_mean(width: int, height: int, get) -> tuple[float, float, float]:
    """Mean rgb of the open ground, selected exactly as `build_mask.py` selects it."""
    n = 0
    r = g = b = 0
    for y in range(0, height, SAMPLE):
        for x in range(0, width, SAMPLE):
            R, G, B = get(x, y)
            if not is_water(R, G, B) and is_open(R, G, B):
                n += 1
                r += R
                g += G
                b += B
    if n == 0:
        raise SystemExit("no open ground found - is this a board?")
    return r / n, g / n, b / n


def grass_weight(r: int, g: int, b: int) -> float:
    """How much of the grade this pixel takes: 1 on meadow, 0 on canopy, water and stone."""
    if is_water(r, g, b):
        return 0.0
    w = (g - b - WEIGHT_FLOOR) / WEIGHT_RAMP
    return 0.0 if w < 0.0 else (1.0 if w > 1.0 else w)


## Box-blur radius used by --smooth, in source pixels. Sized against the thing it exists to
## kill: a generated meadow's leaf/clover stipple runs 10-20px across at 1672 wide, so a
## 7x7 window softens it without erasing the larger mown variation that keeps grass from
## reading as flat paint. Bigger is not better here - at radius 6 the meadow turns to felt.
SMOOTH_RADIUS = 3


def box_blur(src: Png, radius: int) -> list[bytearray]:
    """Separable box blur over the whole image, as three channel planes.

    Blurred everywhere and composited selectively afterwards: filtering only the grass in
    place would pull road and tree colour in across the boundary, which is how a selective
    blur grows a halo around every object standing in the meadow.
    """
    w, h = src.width, src.height
    planes = []
    for c in range(3):
        flat = bytearray(w * h)
        for y in range(h):
            row = y * w
            for x in range(w):
                flat[row + x] = src.rgb(x, y)[c]
        # Horizontal pass, then vertical, each with a running sum so the cost does not
        # depend on the radius.
        tmp = bytearray(w * h)
        for y in range(h):
            row = y * w
            acc = sum(flat[row:row + min(radius + 1, w)])
            n = min(radius + 1, w)
            for x in range(w):
                tmp[row + x] = acc // n
                add, drop = x + radius + 1, x - radius
                if add < w:
                    acc += flat[row + add]; n += 1
                if drop >= 0:
                    acc -= flat[row + drop]; n -= 1
        out = bytearray(w * h)
        for x in range(w):
            acc = sum(tmp[y * w + x] for y in range(min(radius + 1, h)))
            n = min(radius + 1, h)
            for y in range(h):
                out[y * w + x] = acc // n
                add, drop = y + radius + 1, y - radius
                if add < h:
                    acc += tmp[add * w + x]; n += 1
                if drop >= 0:
                    acc -= tmp[drop * w + x]; n -= 1
        planes.append(out)
    return planes


def render(src: Png, shift: list[float], smooth: float = 0.0,
           blurred: list[bytearray] | None = None) -> bytearray:
    out = bytearray(src.width * src.height * 4)
    for y in range(src.height):
        for x in range(src.width):
            r, g, b = src.rgb(x, y)
            w = grass_weight(r, g, b)
            i = (y * src.width + x) * 4
            if smooth > 0.0 and blurred is not None and w > 0.0:
                # Toward the blurred version by weight x strength, so the road, the trees
                # and the cliffs keep every pixel of their sharpness and only the meadow
                # loses its stipple. The weight doing double duty here is deliberate: the
                # pixels this softens are exactly the ones the grade lifts and exactly the
                # ones build_mask.py calls buildable.
                t = w * smooth
                j = y * src.width + x
                r = r + (blurred[0][j] - r) * t
                g = g + (blurred[1][j] - g) * t
                b = b + (blurred[2][j] - b) * t
            out[i] = max(0, min(255, int(round(r + w * shift[0]))))
            out[i + 1] = max(0, min(255, int(round(g + w * shift[1]))))
            out[i + 2] = max(0, min(255, int(round(b + w * shift[2]))))
            out[i + 3] = 255
    return out


def main() -> int:
    args = [a for a in sys.argv[1:]]
    smooth = 0.0
    if "--smooth" in args:
        i = args.index("--smooth")
        smooth = float(args[i + 1])
        del args[i:i + 2]
    reference = DEFAULT_REFERENCE
    if "--against" in args:
        i = args.index("--against")
        reference = args[i + 1]
        del args[i:i + 2]
    if not args:
        print(__doc__.strip().splitlines()[-6])
        return 1
    board_path = args[0]
    out_path = args[1] if len(args) > 1 else board_path[:-4] + "_graded.png"

    src = Png(board_path)
    ref = Png(reference)
    target = open_mean(ref.width, ref.height, ref.rgb)
    start = open_mean(src.width, src.height, src.rgb)
    print("reference {}".format(os.path.basename(reference)))
    print("  grass rgb ({:.1f}, {:.1f}, {:.1f})   <- the target".format(*target))
    print("board {}".format(os.path.basename(board_path)))
    print("  grass rgb ({:.1f}, {:.1f}, {:.1f})".format(*start))

    blurred = None
    if smooth > 0.0:
        print("  smoothing the grass: radius {}px at strength {:.2f}"
              .format(SMOOTH_RADIUS, smooth))
        blurred = box_blur(src, SMOOTH_RADIUS)

    shift = [target[i] - start[i] for i in range(3)]
    out = bytearray()
    for step in range(PASSES):
        out = render(src, shift, smooth, blurred)

        def get(x: int, y: int, _o=out, _w=src.width):
            i = (y * _w + x) * 4
            return _o[i], _o[i + 1], _o[i + 2]

        got = open_mean(src.width, src.height, get)
        print("  pass {}: shift ({:+.1f}, {:+.1f}, {:+.1f}) -> ({:.1f}, {:.1f}, {:.1f})"
              .format(step, shift[0], shift[1], shift[2], *got))
        if step == PASSES - 1:
            break
        for i in range(3):
            gained = got[i] - start[i]
            wanted = target[i] - start[i]
            if abs(gained) > 1.0:
                shift[i] *= wanted / gained

    write_rgba(out_path, src.width, src.height, bytes(out))
    print("  wrote {}".format(out_path))
    print("\nNext: rebuild the masks FROM THE GRADED FILE, then measure:")
    print("  python tools/build_mask.py {}".format(out_path))
    print("  python tools/art_match.py {} --against {}".format(out_path, board_path))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
