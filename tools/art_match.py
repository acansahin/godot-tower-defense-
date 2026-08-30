#!/usr/bin/env python3
"""Measure whether the towers and the board look like the same picture.

The complaint this answers is "the towers do not look like they belong on the map", and
until this file existed the only way to argue about it was to look at a screenshot. That is
the position placement was in before `--dump-board`: a real defect, no number, and several
plausible fixes that all sound right.

Four things are measured. The first is about PLAYABILITY and the rest about looks:

* **How much of the shootable band is open.** A tower must stand clear of the road and can
  only reach 300px, so ground outside the 70-300px band is scenery however open it is. This
  is the number a board lives or dies on and no other tool reports it: `--dump-board` counts
  pads, which also depends on `PAD_PITCH` and the origin search, and `build_mask.py` reports
  open ground over the whole image, which a board can win with one empty corner the road
  never visits.

* **The camera.** A circle lying flat on the ground is drawn `sin(elevation)` times as tall
  as it is wide. Nothing on a board is labelled "circle", but the ROAD is a ribbon of
  constant width, so its drawn width where it runs north-south (measured across, in x) is
  the true width, and where it runs east-west (measured across, in y) is the squashed one.
  The ratio of the two IS the board's ground squash. Compare it to the squash the tower
  sheets were painted at - `tower.gd`'s WATER_POOL / NATURE_RUNE tables, both hand-measured
  ground circles, sit at 0.24-0.30 - and to `Game.GROUND_SQUASH`, which is what the engine
  draws its shadows and pads at.

  Read the LOW percentile of the run lengths, never the median. A scanline crossing a road
  running at angle f to it cuts a chord of `w / sin(f)`, so every direction but the
  perpendicular one INFLATES the width; the minimum is the only honest sample. The median
  measures the board's average road direction, which is not a thing anyone wants to know.

* **Where the tower actually stands.** Averaging a whole board is misleading: the trees are
  most of the pixels and no tower stands on a tree. Open ground is selected through the
  same test `build_mask.py` uses, so this measures the grass the masonry is dropped onto.

* **The tower's masonry, not its glow.** Only the LOWER HALF of each sprite is measured. A
  tower's top quarter is flame, crystal or light by design (see docs/tower-art-prompt.md's
  effect-restraint rule), and including it says a Fire tower is bright when what is being
  asked is whether its STONE sits on the grass.

The blue channel is the one to read first. Measured on the winding board, nothing painted
on it carries blue above ~32 while every tower's masonry carries 44-114 - neutral grey
stone on a yellow-green ground with no blue in it reads as a foreign object however well
lit it is, and no amount of value grading fixes a hue the board does not contain.

Usage::

    python tools/art_match.py                  # the board a Standard run plays on
    python tools/art_match.py <board.png>      # a CANDIDATE, before wiring it into Game
    python tools/art_match.py <new.png> --against <old.png>   # did an EDIT move the road?

The second form is the point of the tool: connecting a new board takes hours (hand-tracing
the road, the two masks, the use_board branch) and re-running a prompt takes minutes, so
measure the image before believing it.

The third answers the one question an EDITED board raises. Editing a board rather than
regenerating one is worth doing precisely because the road does not move, which keeps
`Game.WINDING_PATH` and skips the re-trace entirely - but image models asked to change part
of a picture routinely hand back a whole new one, and a road in almost the right place looks
fine while walking enemies through the grass. Check before believing the edit was local.
"""

from __future__ import annotations

import colorsys
import glob
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from build_mask import BLOCK, is_open, is_water  # noqa: E402  the same tests, on purpose
from png_reader import Png  # noqa: E402

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(HERE, "godottowerdefense", "assets", "art")
## The board `main.gd`'s STANDARD_BOARD resolves to. Every other board is a harness's.
DEFAULT_BOARD = os.path.join(ART, "maps", "winding_forest_close_v1.png")
TOWERS = os.path.join(ART, "towers")

## What a board has to hit for the current roster to sit on it. Both figures are measured
## off board_source.png - the board the six element sets were actually generated against,
## and the one they visibly belong to - so they are targets rather than opinions. Re-derive
## them by running this tool on that board if the roster is ever repainted.
TARGET_OPEN_LUM = 105.0     # board_source.png open ground reads 106.4; winding reads 73.3
## How much bluer than its ground the masonry may sit before grey stone stops reading as
## part of the painting. Anchored the same way: against board_source.png's open ground
## (blue 35.6) the roster's median masonry sits 11 above, and against the winding board
## (blue 25.1) it sits 21 above. The line goes between the board that works and the one
## that does not.
BLUE_TOLERANCE = 15.0
## Between the towers' own 0.24-0.30 and a flat overhead 1.0. At the towers' figure the
## ground is nearly edge-on and the playfield collapses; half puts the board within ~15
## degrees of the roster, which is the gap a coherent board lives at. Note that BOTH boards
## in the repo measure ~1.0, so this is the one target with no working example behind it -
## board_source.png is the better board on value and hue, not on camera. See
## docs/board-art-prompt.md.
TARGET_SQUASH = 0.50
## How far off target each check is still allowed to read OK.
LUM_TOLERANCE = 8.0
SQUASH_TOLERANCE = 0.15
## `Game.ROAD_HALF`: a waypoint within this of the new road still walks enemies on cobbles.
ROAD_HALF = 40.0
## How much of the old road must still be on the new one for the traced path to be reusable.
ROAD_HELD_PCT = 95.0
## Crossings needed on EACH axis before a squash figure means anything. board_source.png
## yields 4 and 5 - its road is broken up by tree crowns - and the ratio of two samples that
## small is noise wearing three decimal places.
MIN_CROSSINGS = 50


def is_cobble(r: int, g: int, b: int) -> bool:
    """Pale, bright, and not the yellow-green meadow.

    Deliberately NOT trace_road.py's test: that one is tuned to find the spiral's road from
    the keep outward and returns fragments on a winding board (18px runs on an 87px road),
    which is fine for tracing a centre-line and useless for measuring a width.
    """
    return (r + g + b) > 210 and (g - b) < 45 and r >= g - 10 and b > 40


def lum(r: int, g: int, b: int) -> float:
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


class Bucket:
    """Running mean of luminance, saturation and rgb over a set of pixels."""

    def __init__(self) -> None:
        self.n = 0
        self.lum = self.sat = 0.0
        self.r = self.g = self.b = 0.0

    def add(self, r: int, g: int, b: int) -> None:
        _h, s, _v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
        self.n += 1
        self.lum += lum(r, g, b)
        self.sat += s
        self.r += r
        self.g += g
        self.b += b

    def mean_lum(self) -> float:
        return self.lum / max(self.n, 1)

    def mean_blue(self) -> float:
        return self.b / max(self.n, 1)

    def row(self, name: str) -> str:
        n = max(self.n, 1)
        return ("  {:34s} n={:8d}  lum={:6.1f}  sat={:5.3f}  rgb=({:5.1f},{:5.1f},{:5.1f})"
                .format(name, self.n, self.lum / n, self.sat / n,
                        self.r / n, self.g / n, self.b / n))


def board_palette(img: Png) -> tuple[Bucket, Bucket, Bucket]:
    """(everything, open ground, closed ground), open ground by build_mask.py's own test.

    Computed from the painting rather than read out of `<board>_build.png`, so a candidate
    board can be measured before any mask has been generated for it.
    """
    every, opens, closed = Bucket(), Bucket(), Bucket()
    area = float(BLOCK * BLOCK)
    for by in range(img.height // BLOCK):
        for bx in range(img.width // BLOCK):
            block = []
            hits = wet = 0
            for y in range(by * BLOCK, (by + 1) * BLOCK):
                for x in range(bx * BLOCK, (bx + 1) * BLOCK):
                    rgb = img.rgb(x, y)
                    block.append(rgb)
                    every.add(*rgb)
                    if is_water(*rgb):
                        wet += 1
                    elif is_open(*rgb):
                        hits += 1
            # build_mask.py's own thresholds, kept here so the two files cannot drift: a
            # block is open if enough of it is, and never if it holds real water.
            into = opens if (wet / area < 0.20 and hits / area >= 0.30) else closed
            for rgb in block:
                into.add(*rgb)
    return every, opens, closed


def road_runs(img: Png, axis: int, min_len: int = 30, max_len: int = 400) -> list[int]:
    """Lengths of the road's crossings along one axis. axis 0 scans rows, 1 scans columns."""
    out: list[int] = []
    outer = img.height if axis == 0 else img.width
    inner = img.width if axis == 0 else img.height
    for i in range(outer):
        run = 0
        for j in range(inner):
            x, y = (j, i) if axis == 0 else (i, j)
            if is_cobble(*img.rgb(x, y)):
                run += 1
                continue
            if min_len <= run <= max_len:
                out.append(run)
            run = 0
        # The run still open at the edge counts too - the road leaves the canvas at both
        # ends, so dropping it would throw away two of the cleanest crossings on the board.
        if min_len <= run <= max_len:
            out.append(run)
    out.sort()
    return out


def ground_squash(img: Png) -> tuple[float, str]:
    """The board's ground squash, and a line saying what it was read off."""
    across = road_runs(img, 0)   # scanning rows: narrowest where the road runs N-S
    down = road_runs(img, 1)     # scanning cols: narrowest where the road runs E-W
    if len(across) < MIN_CROSSINGS or len(down) < MIN_CROSSINGS:
        return 0.0, ("  road: only {:d}/{:d} crossings found, need {:d} on each axis"
                     " - too little clean cobble to measure a camera from"
                     .format(len(across), len(down), MIN_CROSSINGS))

    def low(a: list[int]) -> int:
        return a[min(int(len(a) * 0.10), len(a) - 1)]

    true_w, flat_w = low(across), low(down)
    detail = ("  road width  N-S {:3d}px (n={:d})   E-W {:3d}px (n={:d})"
              .format(true_w, len(across), flat_w, len(down)))
    return (flat_w / true_w if true_w else 0.0), detail


## The band a tower can actually shoot into, in WORLD px: it must stand at least
## Game.ROAD_KEEPOUT (83) from the road centre-line, and Balance.MAX_TOWER_RANGE caps its
## reach at 300. Ground outside this band is scenery no matter how open it is.
BAND_NEAR = 70.0
BAND_FAR = 300.0
## 1672 painting px are drawn across 1536 world px.
WORLD_PER_BOARD = 1536.0 / 1672.0
## What the band has to be for the board to be worth building on. The winding board measures
## 17%, which is 12 pads; the target is a road with a continuous open apron down both sides.
TARGET_BAND_OPEN = 80.0


def band_open_fraction(img: Png) -> tuple[float, str]:
    """How much of the shootable band beside the road is open ground.

    THE number this repaint exists for, and the one no other tool reports: `--dump-board`
    counts pads (an answer that also depends on PAD_PITCH and the origin search) and
    `build_mask.py` reports open ground over the WHOLE image (which a board can win by
    having a big empty corner the road never goes near). What decides whether a board is
    playable is narrower — open ground close enough to the road to shoot at it.

    Worked at BLOCK resolution, the same 8px grid the build mask uses, so a multi-source
    breadth-first walk out from the road is a few thousand cells rather than a distance
    transform over 1.5 million pixels.
    """
    bw, bh = img.width // BLOCK, img.height // BLOCK
    area = float(BLOCK * BLOCK)
    road = bytearray(bw * bh)
    opens = bytearray(bw * bh)
    for by in range(bh):
        for bx in range(bw):
            cobble = wet = hits = 0
            for y in range(by * BLOCK, (by + 1) * BLOCK):
                for x in range(bx * BLOCK, (bx + 1) * BLOCK):
                    r, g, b = img.rgb(x, y)
                    if is_cobble(r, g, b):
                        cobble += 1
                    if is_water(r, g, b):
                        wet += 1
                    elif is_open(r, g, b):
                        hits += 1
            i = by * bw + bx
            road[i] = 1 if cobble / area >= 0.60 else 0
            opens[i] = 1 if (wet / area < 0.20 and hits / area >= 0.30) else 0

    INF = 1 << 30
    dist = [INF] * (bw * bh)
    queue = [i for i in range(bw * bh) if road[i]]
    for i in queue:
        dist[i] = 0
    head = 0
    while head < len(queue):
        i = queue[head]
        head += 1
        bx, by = i % bw, i // bw
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = bx + dx, by + dy
            if 0 <= nx < bw and 0 <= ny < bh:
                j = ny * bw + nx
                if dist[j] == INF:
                    dist[j] = dist[i] + 1
                    queue.append(j)
    if not queue:
        return 0.0, "  band: no road found, so there is no band to measure"

    # One block step is BLOCK painting px; the four-way walk overstates diagonals, which is
    # conservative here (it pulls far ground into the band, never the reverse).
    step = BLOCK * WORLD_PER_BOARD
    total = free = 0
    for i in range(bw * bh):
        d = dist[i] * step
        if BAND_NEAR <= d <= BAND_FAR:
            total += 1
            free += opens[i]
    if total == 0:
        return 0.0, "  band: empty (is the road one continuous ribbon?)"
    pct = 100.0 * free / total
    return pct, ("  band {:.0f}-{:.0f}px from the road: {:.1f}% open ({:d} of {:d} blocks)"
                 .format(BAND_NEAR, BAND_FAR, pct, free, total))


def tower_base(path: str, fraction: float = 0.5) -> Bucket:
    """The masonry: the lowest `fraction` of the sprite's ink, effects excluded."""
    img = Png(path)
    bucket = Bucket()
    rows = [y for y in range(img.height)
            if any(img.rgba(x, y)[3] > 200 for x in range(0, img.width, 7))]
    if not rows:
        return bucket
    top, bottom = min(rows), max(rows)
    for y in range(int(bottom - (bottom - top) * fraction), bottom + 1):
        for x in range(img.width):
            r, g, b, a = img.rgba(x, y)
            if a > 200:
                bucket.add(r, g, b)
    return bucket


def road_agreement(new: Png, old: Png) -> str:
    """Did an EDIT of a board leave the road where it was?

    The whole value of editing a board rather than regenerating one is that the road does
    not move, so `Game.WINDING_PATH` survives and nobody re-traces 36 control points by
    hand. Image models do not honour that reliably - asked to change part of a picture they
    often return a whole new one - and the failure is quiet, because a road in almost the
    right place looks fine and walks enemies through the grass.

    Compared at BLOCK resolution: a block is road if most of it is cobble, and the two
    boards are scored by how much of their road blocks coincide (intersection over union).
    """
    if (new.width, new.height) != (old.width, old.height):
        return ("  ROAD MOVED: image is {}x{}, original was {}x{} - a resize moves every"
                " pixel, so the road must be re-traced"
                .format(new.width, new.height, old.width, old.height))
    area = float(BLOCK * BLOCK)

    def mask(img: Png) -> set:
        out = set()
        for by in range(img.height // BLOCK):
            for bx in range(img.width // BLOCK):
                hits = 0
                for y in range(by * BLOCK, (by + 1) * BLOCK):
                    for x in range(bx * BLOCK, (bx + 1) * BLOCK):
                        if is_cobble(*img.rgb(x, y)):
                            hits += 1
                if hits / area >= 0.60:
                    out.add((bx, by))
        return out

    a, b = mask(new), mask(old)
    if not a or not b:
        return "  road: no cobble found in one of the images"

    # NOT intersection-over-union. The first version of this check used IoU and called a
    # good edit a failure: an edit that keeps the route but paints the road 6% narrower
    # scores 79% by area while its centre-line has not moved at all, and the road's WIDTH
    # is not what `Game.WINDING_PATH` encodes. What matters is DISPLACEMENT - how far the
    # old road sits from the new one - measured against ROAD_HALF, since a waypoint still
    # within half a road width is still on the road and still walks enemies over cobbles.
    bw = new.width // BLOCK
    bh = new.height // BLOCK
    INF = 1 << 30
    dist = [INF] * (bw * bh)
    queue = [by * bw + bx for (bx, by) in a]
    for i in queue:
        dist[i] = 0
    head = 0
    while head < len(queue):
        i = queue[head]
        head += 1
        bx, by = i % bw, i // bw
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = bx + dx, by + dy
            if 0 <= nx < bw and 0 <= ny < bh:
                j = ny * bw + nx
                if dist[j] == INF:
                    dist[j] = dist[i] + 1
                    queue.append(j)

    step = BLOCK * WORLD_PER_BOARD
    offsets = sorted(dist[by * bw + bx] * step for (bx, by) in b)
    held = sum(1 for v in offsets if v <= ROAD_HALF)
    pct = 100.0 * held / len(offsets)
    median = offsets[len(offsets) // 2]
    p90 = offsets[min(int(len(offsets) * 0.90), len(offsets) - 1)]
    line = ("  road blocks {:d} new / {:d} original ({:+.1f}% area)\n"
            "  old road's distance from the new one: median {:.0f}px, p90 {:.0f}px\n"
            "  {:.1f}% of it is still within ROAD_HALF ({:.0f}px) of the new road"
            .format(len(a), len(b), 100.0 * len(a) / len(b) - 100.0,
                    median, p90, pct, ROAD_HALF))
    if pct >= ROAD_HELD_PCT:
        return line + "\n  ROAD HELD: Game.WINDING_PATH can be kept as it is"
    return (line + "\n  ROAD MOVED: below the {:.0f}% bar - re-trace the path"
            .format(ROAD_HELD_PCT))


def tower_sets() -> list[str]:
    """Every painted set, named the way `Tower.art_key()` names it."""
    names = set()
    for path in glob.glob(os.path.join(TOWERS, "*_3.png")):
        base = os.path.basename(path)
        if not base.startswith("_source"):
            names.add(base[:-len("_3.png")])
    return sorted(names)


def verdict(label: str, ok: bool, complaint: str) -> str:
    return "  {:24s} {}".format(label, "OK" if ok else complaint)


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    board_path = args[0] if args else DEFAULT_BOARD
    if not os.path.exists(board_path):
        print("no such board: {}".format(board_path))
        return 1
    img = Png(board_path)

    # `--against <board>` answers the one question an EDITED board raises: did the road
    # survive? Nothing else in this tool compares two images, and nothing else needs to.
    against = ""
    for i, a in enumerate(sys.argv):
        if a == "--against" and i + 1 < len(sys.argv):
            against = sys.argv[i + 1]
    if against:
        if not os.path.exists(against):
            print("no such board to compare against: {}".format(against))
            return 1
        print("EDIT CHECK  against {}".format(os.path.relpath(against, HERE)))
        print(road_agreement(img, Png(against)))
        print()

    print("BOARD  {}  {}x{}".format(os.path.relpath(board_path, HERE), img.width, img.height))
    every, opens, closed = board_palette(img)
    print(every.row("everything"))
    print(opens.row("open ground (towers stand here)"))
    print(closed.row("closed (trees / rock / water)"))

    band, band_detail = band_open_fraction(img)
    print()
    print("BUILDABLE BAND  open ground near enough to the road to shoot at it")
    print(band_detail)
    print("  target {:.0f}%   (winding measures 17%, which is 12 pads)".format(TARGET_BAND_OPEN))

    squash, detail = ground_squash(img)
    print()
    print("CAMERA  a flat circle is drawn sin(elevation) as tall as it is wide")
    print(detail)
    if squash:
        print("  board ground squash            {:5.3f}   (1.000 = straight overhead)"
              .format(squash))
    print("  tower sheets, hand-measured    0.240-0.300  (tower.gd WATER_POOL/NATURE_RUNE)")
    print("  target for a replacement board {:5.3f}".format(TARGET_SQUASH))

    print()
    print("TOWERS  lower half only: the masonry, not the flame on top of it")
    bases: list[Bucket] = []
    for name in tower_sets():
        bucket = tower_base(os.path.join(TOWERS, "{}_3.png".format(name)))
        if bucket.n:
            bases.append(bucket)
            print(bucket.row(name))
    if not bases:
        print("  no painted tower sets found under {}".format(TOWERS))
        return 1

    open_lum = opens.mean_lum()
    open_blue = opens.mean_blue()
    lums = sorted(b.mean_lum() for b in bases)
    blues = sorted(b.mean_blue() for b in bases)
    # The MEDIAN set, not the darkest one. One tower happening to sit in the board's
    # register says nothing about the roster - infernal alone passes the hue test on a
    # board every other set is foreign on.
    mid_blue = blues[len(blues) // 2]
    print()
    print("VERDICT")
    print("  open ground luminance {:6.1f}  (target {:.0f})".format(open_lum, TARGET_OPEN_LUM))
    print("  tower masonry         {:6.1f} - {:6.1f}".format(lums[0], lums[-1]))
    print("  open ground blue      {:6.1f}".format(open_blue))
    print("  tower masonry blue    {:6.1f} - {:6.1f}   median {:.1f}"
          .format(blues[0], blues[-1], mid_blue))
    if squash:
        print("  ground squash         {:6.3f}  (target {:.2f})".format(squash, TARGET_SQUASH))
    print()
    print(verdict("buildable band", band >= TARGET_BAND_OPEN,
                  "TOO CLOSED - {:.0f}% open beside the road, want {:.0f}%"
                  .format(band, TARGET_BAND_OPEN)))
    print(verdict("value", open_lum >= TARGET_OPEN_LUM - LUM_TOLERANCE,
                  "TOO DARK - the masonry is lit for a brighter board than this one"))
    print(verdict("hue", mid_blue <= open_blue + BLUE_TOLERANCE,
                  "GREY STONE ON BLUE-FREE GROUND - the board has no hue to hold it"))
    if squash:
        print(verdict("camera", abs(squash - TARGET_SQUASH) <= SQUASH_TOLERANCE,
                      "MISMATCH - the board and the towers are not the same view"))
    else:
        print("  {:24s} {}".format("camera", "NOT MEASURED - see the road line above"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
