"""Trace the painted road's centre-line out of the board image into Game.PATH waypoints.

The map is a spiral around the keep, so the road is found by casting rays from the keep:
along each ray the cobble shows up as one band per arm of the spiral, and following the band
whose radius changes least from one ray to the next walks the spiral inward.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from png_reader import Png  # noqa

IMG = os.path.join(os.path.dirname(os.path.abspath(__file__)), os.pardir,
                   "godottowerdefense", "assets", "art", "board_source.png")
WORLD = (1536.0, 864.0)

img = Png(IMG)
SX, SY = WORLD[0] / img.width, WORLD[1] / img.height


def is_road(x, y):
    if x < 0 or y < 0 or x >= img.width or y >= img.height:
        return False
    r, g, b = img.rgb(int(x), int(y))
    # Pale tan cobble: bright, warm, and clearly not the green of the grass.
    return r > 150 and g > 130 and b < g and (r - b) > 40


def bands(cx, cy, theta, r_max, step=2.0, min_width=10.0):
    """Radii where the ray crosses the road, as (centre_r, width) per crossing."""
    out = []
    run_start = None
    r = 20.0
    dx, dy = math.cos(theta), math.sin(theta)
    while r < r_max:
        hit = is_road(cx + dx * r, cy + dy * r)
        if hit and run_start is None:
            run_start = r
        elif not hit and run_start is not None:
            width = r - run_start
            if width >= min_width:
                out.append(((run_start + r) * 0.5, width))
            run_start = None
        r += step
    if run_start is not None and (r - run_start) >= min_width:
        out.append(((run_start + r) * 0.5, r - run_start))
    return out


def find_centre(guess=(915, 400), radius=90):
    """The keep is the dark blob at the middle of the innermost loop."""
    best, best_score = guess, -1
    for y in range(guess[1] - radius, guess[1] + radius, 4):
        for x in range(guess[0] - radius, guess[0] + radius, 4):
            dark = 0
            for dy in range(-20, 21, 5):
                for dx in range(-20, 21, 5):
                    r, g, b = img.rgb(min(max(x + dx, 0), img.width - 1),
                                      min(max(y + dy, 0), img.height - 1))
                    if r + g + b < 260:
                        dark += 1
            if dark > best_score:
                best_score, best = dark, (x, y)
    return best


cx, cy = find_centre()
print(f"keep centre  : ({cx}, {cy}) px  -> world ({cx * SX:.0f}, {cy * SY:.0f})")

# Where the road leaves the left edge: scan the left border for road pixels.
# The very edge is often trees, so walk inward until a column carries a real road run.
entry_y = None
for x in range(4, 200, 4):
    runs, start = [], None
    for y in range(img.height):
        hit = is_road(x, y)
        if hit and start is None:
            start = y
        elif not hit and start is not None:
            if y - start > 20:
                runs.append((start + y) // 2)
            start = None
    if runs:
        entry_y = runs[0]
        print(f"entry column : x={x}, road runs at y={runs}")
        break
print(f"left entry   : y={entry_y}px -> world y {entry_y * SY:.0f}")

start_theta = math.atan2(entry_y - cy, 0 - cx)
r_max = math.hypot(max(cx, img.width - cx), max(cy, img.height - cy))

# Walk from the INSIDE out. Starting at the entry means starting on the one part of the
# road that is not a spiral arm — a straight run in from the edge — and the first ray that
# leaves the picture ends the trace. The innermost arm is small, fully inside the image and
# unambiguous, so the walk starts there and the result is reversed at the end.
def walk(direction, radius):
    """Follow the road from the start ray, one angular direction, until it runs out."""
    theta = start_theta
    run = []
    misses = 0
    for _ in range(4000):
        theta += direction * math.radians(2.0)
        found = bands(cx, cy, theta, r_max)
        near = [b for b in found if abs(b[0] - radius) <= 44.0]
        if not near:
            # A tree or a rock sitting on the road hides it for a ray or two; only give up
            # once the road has really gone.
            misses += 1
            if misses > 6:
                break
            continue
        misses = 0
        pick = min(near, key=lambda b: abs(b[0] - radius))
        radius = pick[0]
        run.append((theta, radius))
        if radius < 40.0 or radius > r_max * 0.95:
            break
    return run


# BOTH angular directions from the same starting band. The spiral is monotonic in radius, so
# one way winds in toward the keep and the other unwinds out toward the edge; walking only
# one of them gets half a road, which is what the first attempt produced.
seed = bands(cx, cy, start_theta, r_max)
assert seed, "no road on the entry ray"
seed_radius = min(b[0] for b in seed if b[0] > 120.0)
inward = walk(+1, seed_radius)
outward = walk(-1, seed_radius)
if inward and outward and inward[-1][1] > outward[-1][1]:
    inward, outward = outward, inward
best_run = list(reversed(outward)) + [(start_theta, seed_radius)] + inward

print(f"traced       : {len(best_run)} rays, radius {best_run[0][1]:.0f} -> "
      f"{best_run[-1][1]:.0f}px")

# Extend the two ends the ray-walk cannot see. The trace covers the spiral arms; what it
# misses is the straight run in from the left edge (not an arc, so the walk never starts on
# it) and the last approach to the keep (too close in for a band to separate from the
# building). Both are extrapolated along the heading the trace ended on and then checked by
# eye against the painting — this is a tracing tool, not a proof.
if len(best_run) > 6:
    (t1, r1), (t2, r2) = best_run[-3], best_run[-1]
    dt = (t2 - t1) / 2.0
    dr = (r2 - r1) / 2.0
    theta, radius = t2, r2
    while radius > 60.0:
        theta += dt
        radius = max(50.0, radius + (dr if dr < -2.0 else -18.0))
        best_run.append((theta, radius))

# Thin the run into waypoints and convert to world space.
points = []
for i, (theta, radius) in enumerate(best_run):
    if i % 5 and i != len(best_run) - 1:
        continue
    x = (cx + math.cos(theta) * radius) * SX
    y = (cy + math.sin(theta) * radius) * SY
    points.append((x, y))

# The entry: the painted road crosses the left edge at entry_y, and enemies spawn beyond it.
points.insert(0, (0.0, entry_y * SY))
points.insert(0, (-144.0, entry_y * SY))
# The keep is where the road ends, so the last waypoint IS the keep.
points.append((cx * SX, cy * SY))

total = sum(math.dist(points[i], points[i + 1]) for i in range(len(points) - 1))
print(f"waypoints    : {len(points)}, road length {total:.0f}px")
print("const PATH: Array = [")
for x, y in points:
    print(f"\tVector2({x:.0f}, {y:.0f}),")
print("]")
