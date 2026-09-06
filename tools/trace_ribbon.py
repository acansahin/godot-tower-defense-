#!/usr/bin/env python3
"""Trace ANY road out of a board painting into `Game.<NAME>_PATH` control points.

`trace_road.py` only works on the spiral: it casts rays from the keep at the centre and
follows the cobble band inward, which cannot follow an S, a diagonal or a hook. Every other
board's road has therefore been read off the painting BY HAND -- `Game.WINDING_PATH`'s 36
points and `Game.S_PATH`'s 32 were both typed out by eye -- and that hand-tracing is the
single most expensive step in adding a map, which is what has kept the roster at three.

This does it by marching instead of by ray-casting, so the shape of the road does not matter:

1. Threshold the painting against a DECLARED road colour (`--road`), at 4px resolution.
2. Distance-transform the result, so every road cell knows how deep inside the ribbon it is.
   The ridge of that transform is the centre-line.
3. Find the road's two ENDS as the graph diameter of the road cells: breadth-first from any
   cell to find the farthest, then breadth-first from there. This is the standard two-pass
   trick and it finds the true extremities of a ribbon whatever it is shaped like.
4. Walk the shortest path between them, then push each point onto the local ridge -- a plain
   shortest path hugs the inside of every curve, and a road that cuts its own corners walks
   enemies through the verge.
5. Resample at `--step` and print a ready-to-paste `const` block in WORLD coordinates.

`--preview` draws the result back over the painting, which is the only check that catches a
line sitting beside the road rather than on it. Do that before pasting anything.

Usage::

    python tools/trace_ribbon.py <board.png> --road=75,82,88 --tol=50 --name=GLACIER
    python tools/trace_ribbon.py <board.png> --road=... --step=34 --preview=check.png

`--road` is the road's own colour, eyedropped off the painting; `--tol` how far a pixel may
sit from it. A road that does not contrast with its ground cannot be traced by this or by any
other means, which is why every brief in docs/board-art-prompt.md fixes the road's value
against the ground it crosses.
"""

from __future__ import annotations

import os
import sys
from collections import deque

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from png_reader import Png, write_rgba  # noqa: E402

CELL = 4               # trace grid resolution, in board px
FILL = 0.5             # fraction of a cell that must match the road colour
WORLD = (1536.0, 864.0)   # Game.WORLD_SIZE; the painting is fitted to this
DEFAULT_STEP = 34.0    # world px between emitted control points
MIN_DEPTH = 2          # cells: ignore road specks thinner than a real road


def road_grid(img: Png, ref, tol: float):
    """Boolean road mask at CELL resolution."""
    gw, gh = img.width // CELL, img.height // CELL
    t2 = tol * tol
    rr, gg, bb = ref
    grid = bytearray(gw * gh)
    need = FILL * CELL * CELL
    for cy in range(gh):
        for cx in range(gw):
            hits = 0
            for y in range(cy * CELL, (cy + 1) * CELL):
                for x in range(cx * CELL, (cx + 1) * CELL):
                    r, g, b = img.rgb(x, y)
                    dr, dg, db = r - rr, g - gg, b - bb
                    if dr * dr + dg * dg + db * db <= t2:
                        hits += 1
            grid[cy * gw + cx] = 1 if hits >= need else 0
    return grid, gw, gh


def depth_map(grid, gw, gh):
    """For each road cell, how many cells deep inside the ribbon it is (BFS from the edge)."""
    INF = 1 << 30
    dist = [0 if not grid[i] else INF for i in range(gw * gh)]
    q = deque(i for i in range(gw * gh) if not grid[i])
    while q:
        i = q.popleft()
        cx, cy = i % gw, i // gw
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = cx + dx, cy + dy
            if 0 <= nx < gw and 0 <= ny < gh:
                j = ny * gw + nx
                if dist[j] > dist[i] + 1:
                    dist[j] = dist[i] + 1
                    q.append(j)
    # A road cell touching the image border has no edge beyond it, so it reads as depth 1 and
    # the trace stops short of where the road actually leaves the picture. Lift those.
    for cy in range(gh):
        for cx in (0, gw - 1):
            i = cy * gw + cx
            if grid[i]:
                dist[i] = max(dist[i], MIN_DEPTH)
    for cx in range(gw):
        for cy in (0, gh - 1):
            i = cy * gw + cx
            if grid[i]:
                dist[i] = max(dist[i], MIN_DEPTH)
    return dist


def bfs(grid, gw, gh, start, allowed):
    """Breadth-first over road cells, returning (dist, parent)."""
    INF = 1 << 30
    dist = [INF] * (gw * gh)
    parent = [-1] * (gw * gh)
    dist[start] = 0
    q = deque([start])
    while q:
        i = q.popleft()
        cx, cy = i % gw, i // gw
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)):
            nx, ny = cx + dx, cy + dy
            if 0 <= nx < gw and 0 <= ny < gh:
                j = ny * gw + nx
                if allowed[j] and dist[j] == INF:
                    dist[j] = dist[i] + 1
                    parent[j] = i
                    q.append(j)
    return dist, parent


def trace(img: Png, ref, tol: float, step: float):
    grid, gw, gh = road_grid(img, ref, tol)
    total = sum(grid)
    if total == 0:
        raise SystemExit("no road found: is --road right? try widening --tol")
    depth = depth_map(grid, gw, gh)
    # Only cells with real thickness take part, so mortar flecks and dark scenery specks that
    # happen to match the road colour cannot become the route.
    allowed = bytearray(1 if (grid[i] and depth[i] >= MIN_DEPTH) else 0 for i in range(gw * gh))
    if not any(allowed):
        raise SystemExit("road found but never %d cells thick: --tol may be too tight" % MIN_DEPTH)

    # THE LARGEST CONNECTED COMPONENT, not the first cell found. Anything else the board
    # paints in the road's colour -- shadowed ice walls, moraine rubble, the gatehouse -- is
    # its own little island, and seeding the diameter search in one of those traced an 11px
    # speck at the top border and reported it as the road.
    best_comp, best_size = None, 0
    seen = bytearray(gw * gh)
    for s in range(gw * gh):
        if not allowed[s] or seen[s]:
            continue
        comp, q = [], deque([s])
        seen[s] = 1
        while q:
            i = q.popleft()
            comp.append(i)
            cx, cy = i % gw, i // gw
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)):
                nx, ny = cx + dx, cy + dy
                if 0 <= nx < gw and 0 <= ny < gh:
                    j = ny * gw + nx
                    if allowed[j] and not seen[j]:
                        seen[j] = 1
                        q.append(j)
        if len(comp) > best_size:
            best_comp, best_size = comp, len(comp)
    keep = bytearray(gw * gh)
    for i in best_comp:
        keep[i] = 1
    allowed = keep
    print("# road: %d cells in the largest run, of %d matching the colour"
          % (best_size, sum(1 for i in range(gw * gh) if grid[i])))

    seed = best_comp[0]
    d1, _ = bfs(grid, gw, gh, seed, allowed)
    a = max((i for i in range(gw * gh) if allowed[i] and d1[i] < (1 << 30)), key=lambda i: d1[i])
    d2, _ = bfs(grid, gw, gh, a, allowed)
    b = max((i for i in range(gw * gh) if allowed[i] and d2[i] < (1 << 30)), key=lambda i: d2[i])
    _, parent = bfs(grid, gw, gh, b, allowed)

    chain = []
    i = a
    while i != -1:
        chain.append(i)
        i = parent[i]
    chain.reverse()   # now runs b -> a; direction is fixed below

    # Push each point onto the ridge: the shortest path hugs the inside of every bend, and a
    # road that cuts its own corners walks enemies along the verge.
    pts = []
    for i in chain:
        cx, cy = i % gw, i // gw
        best, bx, by = depth[i], cx, cy
        for dy in range(-3, 4):
            for dx in range(-3, 4):
                nx, ny = cx + dx, cy + dy
                if 0 <= nx < gw and 0 <= ny < gh:
                    j = ny * gw + nx
                    if grid[j] and depth[j] > best:
                        best, bx, by = depth[j], nx, ny
        pts.append((bx * CELL + CELL * 0.5, by * CELL + CELL * 0.5))

    sx, sy = WORLD[0] / img.width, WORLD[1] / img.height
    world = [(x * sx, y * sy) for x, y in pts]

    out = [world[0]]
    for p in world[1:]:
        lx, ly = out[-1]
        if ((p[0] - lx) ** 2 + (p[1] - ly) ** 2) ** 0.5 >= step:
            out.append(p)
    if out[-1] != world[-1]:
        out.append(world[-1])
    return out, 100.0 * total / (gw * gh)


def preview(img: Png, pts, path: str):
    """The traced line drawn back over the painting. The only check that catches a route
    sitting beside the road rather than on it."""
    W, H = img.width, img.height
    sx, sy = W / WORLD[0], H / WORLD[1]
    out = bytearray(W * H * 4)
    for y in range(H):
        for x in range(W):
            r, g, b = img.rgb(x, y)
            i = (y * W + x) * 4
            out[i], out[i + 1], out[i + 2], out[i + 3] = r, g, b, 255

    def dot(px, py, rad, col):
        for y in range(int(py - rad), int(py + rad) + 1):
            for x in range(int(px - rad), int(px + rad) + 1):
                if 0 <= x < W and 0 <= y < H and (x - px) ** 2 + (y - py) ** 2 <= rad * rad:
                    i = (y * W + x) * 4
                    out[i], out[i + 1], out[i + 2] = col

    for k in range(len(pts) - 1):
        x0, y0 = pts[k][0] * sx, pts[k][1] * sy
        x1, y1 = pts[k + 1][0] * sx, pts[k + 1][1] * sy
        n = max(2, int(((x1 - x0) ** 2 + (y1 - y0) ** 2) ** 0.5))
        for t in range(n + 1):
            dot(x0 + (x1 - x0) * t / n, y0 + (y1 - y0) * t / n, 2.0, (255, 60, 60))
    for p in pts:
        dot(p[0] * sx, p[1] * sy, 5.0, (255, 220, 40))
    dot(pts[0][0] * sx, pts[0][1] * sy, 9.0, (60, 255, 120))     # spawn
    dot(pts[-1][0] * sx, pts[-1][1] * sy, 9.0, (80, 180, 255))   # keep
    write_rgba(path, W, H, bytes(out))


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    flags = {a.split("=")[0]: a.split("=", 1)[-1] for a in sys.argv[1:] if a.startswith("--")}
    if not args or "--road" not in flags:
        print(__doc__)
        return 2
    ref = tuple(int(v) for v in flags["--road"].split(","))
    if len(ref) != 3:
        print("--road wants three numbers, e.g. --road=75,82,88")
        return 2
    tol = float(flags.get("--tol", 50.0))
    step = float(flags.get("--step", DEFAULT_STEP))
    name = flags.get("--name", "NEW")

    img = Png(args[0])
    pts, pct = trace(img, ref, tol, step)

    if "--preview" in flags:
        preview(img, pts, os.path.abspath(flags["--preview"]))

    length = sum(((pts[i + 1][0] - pts[i][0]) ** 2 + (pts[i + 1][1] - pts[i][1]) ** 2) ** 0.5
                 for i in range(len(pts) - 1))
    print("# %s: %d control points, road %.0f px, %.1f%% of the board is road"
          % (os.path.basename(args[0]), len(pts), length, pct))
    print("# spawn %.0f,%.0f  ->  keep %.0f,%.0f"
          % (pts[0][0], pts[0][1], pts[-1][0], pts[-1][1]))
    print("const %s_PATH: Array = [" % name)
    for i in range(0, len(pts), 4):
        row = ", ".join("Vector2(%.0f, %.0f)" % p for p in pts[i:i + 4])
        print("\t%s," % row)
    print("]")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
