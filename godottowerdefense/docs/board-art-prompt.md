# Generating a board painting

The board is the one asset every other asset was generated against: the six tower sets and
all eleven creep cycles were painted by attaching a board and asking the generator to match
its camera, light and palette.

**But the board they were attached to was `assets/art/board_source.png`, the spiral, and the
game is played on the winding board.** So the sentence that used to sit here — "attach the
board being replaced, and change the road and the ground, not the world" — was pointing the
new board at the wrong reference, and following it would have locked in the mismatch this
file now exists to end. The roster committed to a register; a replacement board has to join
it, not the other way round. **Attach the TOWER SHEETS.**

This file is the prompt and the checklist around it. The pipeline it feeds is in
[CLAUDE.md](../../CLAUDE.md) ("The board is measured, not eyeballed"), and every number
below comes out of `python tools/art_match.py`.

## Two paths, and the cheap one comes first

**Every prompt block below opens with its own attachment list, as full paths**, so a copied
prompt carries them and nothing has to be remembered separately. They are absolute for this
checkout — `C:\Users\alica\OneDrive\Belgeler\GitHub\godot-tower-defense-\godottowerdefense\`
— so if the repo moves, the prefix is the only thing to change. The ORDER in each list is
load-bearing: the prompts refer to the attachments as "image 1", "image 2", and so on.

**Path A — EDIT the board that exists.** Clear the trees and rocks out of marked regions
and change nothing else. The road does not move, so `Game.WINDING_PATH` is untouched and
there is NO re-trace. It fixes the build-space problem and only that.

**Path B — GENERATE a replacement board.** Fixes build space, light and camera together,
and costs a full re-trace of the road plus new masks.

They are not exclusive and A does not block B. Do A to get a playable board this afternoon;
do B when the visual mismatch is worth the re-trace.

**Path A is the one to reach for by default**, and the reason is worth stating: the road
layout is already built, traced, balanced and liked. Every path that regenerates the picture
puts that at risk, and a generator asked for "the same map" will still return a different
one. Editing cannot lose what it does not touch.

### Path A: the edit prompt

Attach ONE image — the board with the wanted clearings outlined on it by hand (yellow works;
any colour not otherwise in the painting does).

```text
Edit the attached image. Do not create a new picture: modify this one and return it
otherwise unchanged.

The image is a game map. Yellow outlines have been drawn on it by hand, marking areas
that need to be cleared.

WHAT TO DO - only these three things:
1. Inside every area enclosed by a yellow outline, remove the trees, rocks, boulders,
   basalt columns, stone outcrops, bushes, shrubs, dense flower clumps and undergrowth.
2. Fill the space they leave with the same flat open grass that is already visible in
   the clear meadow patches of this same image - same colour, same texture, same
   lighting. The result must be smooth empty lawn with nothing standing on it and
   nothing casting a shadow onto it.
3. Remove the yellow outlines themselves, completely - no line, no trace, no glow, no
   colour fringe where they were.

WHAT MUST NOT CHANGE - everything else in the image:
- The stone road: same route, same bends, same position, same width, same cobbles. It
  must not shift by a single pixel.
- The waterfall and the river down the LEFT EDGE, and the wet dark cliffs around them.
  Untouched.
- All forest, cliffs, rock columns and scenery OUTSIDE the yellow areas: untouched, in
  place, at the same size.
- The camera angle, the lighting and its direction, the colour palette, the saturation,
  the level of detail, and the painting style.
- The image dimensions and the framing.

This is a local retouch of specific regions, not a repaint and not a redesign. Every
pixel outside the marked areas should come back identical.
```

**What Path A does not fix.** The board stays dim (open ground luminance 73 against the
roster's 105) and stays painted straight down (squash 1.000 against the sheets' 0.24-0.30),
so the towers still read as pasted on. `Game.ART_TINT` can take the edge off the value gap
in one constant; nothing takes the edge off the camera. That is Path B's job.

**Check the edit actually was one.** Image models routinely regenerate a whole picture when
asked to change part of it, which silently costs the road. Before wiring the result in, diff
it against the original: the road pixels must be in the same places. If they moved, Path A
bought nothing and the result has to be treated as a Path B board — re-traced from scratch.

## Why a replacement board would be generated (Path B)

There are two reasons and they are unrelated, which is the good news — one repaint settles
both.

**One: there is nowhere to build.** The winding board
(`assets/art/maps/winding_forest_close_v1.png`) is a dense forest with meadow only in the
interiors of its loops. `tools/art_match.py` reports **22.6% of the band 70-300px from the
road** as open ground — that band being the only ground a tower can both stand on and shoot
from — which comes out as **12 pads on the whole map**. No code change fixes it, because the
rule is read off the painting: loosening `build_mask.py` past this point starts admitting
tree canopy, and towers stand in the branches.

The target is **80%**, and what that means in practice was drawn by hand: the road wants a
continuous open apron down both sides AND the full interior of every bend, with nothing
standing in it. Not "fewer trees" — an apron. That annotated image is attachment 5 in the
template below.

**Two: the towers do not look like they are standing on it.** Measured with
`tools/art_match.py`:

| | winding (played) | board_source (the roster's reference) | the roster |
|---|---|---|---|
| Open-ground luminance | **73.3** | 106.4 | masonry 50-125 |
| Open-ground blue channel | **25.1** | 35.6 | masonry median 46.5 |
| Ground squash (a flat circle's height over its width) | **1.000** | — | **0.24-0.30** |

Three separate faults. The board is lit for a duller day than the towers were painted for;
nothing on it carries blue above ~32, so grey masonry has no hue to sit in; and it is
painted **straight down** while every tower sheet is painted from a low three-quarter view,
a gap no colour grading can close. The engine's own ground decals (`Game.GROUND_SQUASH`)
side with the towers.

**So a replacement has to do three things:** carry a continuous empty apron beside the road,
sit in the roster's light, and be painted from the roster's camera. The apron is the layout
requirement; the other two are the reason this file's reference was inverted. All three are
measured by `art_match.py`, and the winding board fails all three.

## What the tools measure, and what that forbids

Four separate pieces of code read this painting. Each one turns a colour into a rule, and
each one has a failure that looks like an art choice:

| Reader | Test | What breaks the painting |
|---|---|---|
| `build_mask.py` `is_open` | `(g - b) > 35` and `r+g+b > 100` | Grass that is bluish, or grass sitting in shadow. Both are read as canopy, and no tower may stand there |
| `build_mask.py` (block) | 30% of an 8px block must pass | Meadow broken up by fine dark texture — twigs, dense scrub, heavy grass shading |
| `water_mask.py` `is_water` | `b > r+25`, `b > 70`, `g > r` | Water painted grey or green ripples nothing; a bluish grey road ripples like a river |
| `trace_road.py` `is_road` | `r > 140`, `b > 70`, `r > b`, `g > b`, `(r-g) < 45` | A mossy or earth-brown road. The cobble must be a pale grey-tan with real blue in it |

Two of these are worth stating as rules rather than as a table, because they are the ones a
good painter breaks by instinct:

- **A shadow across the meadow deletes the meadow.** The brightness floor exists to drop
  everything under the canopy, and it cannot tell a tree's shade from a dramatic cloud
  shadow or a vignette. Light the open ground flatly and evenly, corner to corner.
- **Yellow-green is the signal, not "green".** Conifers are extremely green. What separates
  the meadow is that it carries almost no blue: measured on the current board grass runs
  (110-128, 110-129, 22-28) and a tree (16, 30, 14). Paint the grass warm and sunlit, and
  the trees dark and blue-green.

## Keep the road. Only the ground around it is wrong.

**The brief asks for the CURRENT road, not a new one.** This is worth stating loudly because
the first version of this file did the opposite — it described a fresh route ("enters at the
LEFT edge about a third of the way down, four or five long bends") and would have thrown away
a layout that is already built, already balanced and already liked. Nothing about the route
is a defect. What is wrong is the terrain beside it, the light on it, and the angle it is
seen from.

`Game.WINDING_PATH`'s 36 control points were read off the painting by hand and smoothed to
141 waypoints. Keeping the layout does **not** make that free — the road still has to be
re-traced, because the camera change moves every pixel of it — but it makes it a far smaller
job: the new control points land near the old ones and can be nudged rather than found.

**The one trade worth knowing.** Pixel-identical road and a corrected camera are mutually
exclusive: a scene redrawn at a lower camera is compressed vertically, so the road's pixels
must move. Keeping `WINDING_PATH` untouched therefore means keeping the top-down camera and
leaving the towers reading as stickers on the board, which is the complaint that started all
of this. The brief chooses the camera and pays for the re-trace. Reverse that only
deliberately.

`tools/trace_road.py` cannot help either way: it only works on the **spiral** board, casting
rays from the keep at the centre and following the cobble band inward. It cannot follow an S.

That is also why the prompt insists the road stay trivially followable: one continuous
ribbon, constant width, never forking, never crossing itself, never disappearing under a
crown or a bridge. Every one of those costs an hour of hand-tracing.

## The camera, written as a measurement

The old brief said "the same slightly-above three-quarter view, the same elevation", and it
produced a board painted from **straight overhead**. That is what a vague camera instruction
is worth: the phrase is agreeable and unfalsifiable, and nothing in it can be checked.

A circle lying flat on the ground is drawn `sin(elevation)` times as tall as it is wide, so
the camera IS a number and the road reports it. A ribbon of constant width is drawn at its
true width where it runs north-south and squashed where it runs east-west, and the ratio of
the two is the answer. `tools/art_match.py` reads it off any board.

| | ratio | what it looks like |
|---|---|---|
| Winding board today | 1.00 | straight down; no side of anything is visible |
| **Target for a replacement** | **0.50** | a real three-quarter view of the ground |
| The tower sheets | 0.24-0.30 | almost side-on |

**Ask for 0.50, not for the towers' 0.27.** Matching the sheets exactly would put the ground
nearly edge-on, and a tower defense needs to see its playfield: the road would compress into
a thin band and the grass shoulders — the whole point of the repaint — would vanish into
perspective. Half is the meeting point, ~15 degrees off the roster, which is the gap a board
and its towers can live with.

Write it into the prompt as the road, not as degrees, because the road is the thing the
generator is already drawing:

> Where the road runs left-to-right across the picture it must be drawn about HALF as wide
> as where it runs top-to-bottom.

## The projection must be OBLIQUE, not perspective

This is the constraint that is easiest to miss and most expensive to get wrong, and it comes
from the engine rather than from taste.

**The game does not scale sprites by depth.** A tower at the top of the board is drawn at
exactly `TOWER_SPRITE_HEIGHT` (96px) and so is a tower at the bottom; `enemy.gd` likewise
scales a creep by its own radius and nothing else. There is no `z`, no vanishing point and
no camera in the renderer — `map.gd` stretches one image over the world and everything else
is drawn flat on top of it.

So a board painted in true PERSPECTIVE breaks the game rather than merely looking odd. Its
ground converges toward the top of the picture, so the far half of the road is drawn narrower
than the near half — but `Game.ROAD_HALF` is a single constant, so enemies walk a 40px
half-width road over cobbles painted 25px wide at the top and 55px at the bottom. Towers get
the same treatment from `ROAD_KEEPOUT`. The board would need per-row scaling that nothing in
the codebase has.

What is wanted is an **oblique / axonometric** projection: the whole picture compressed
vertically by the same factor everywhere, exactly the way `draw_set_transform(at, 0.0,
Vector2(1.0, Game.GROUND_SQUASH))` compresses every ground decal. Written for a generator:

> Compress the view uniformly. The top of the picture is NOT further away than the bottom.
> Do not converge parallel lines, do not make distant things smaller, do not add a horizon
> or any sky.

`art_match.py`'s squash figure will not catch a perspective board on its own — it reads a
low percentile of the road's width and would report the narrowest part. If a candidate looks
like it recedes, measure the road's width at the TOP of the image against the BOTTOM; on an
oblique board they are equal.

## Constraints that come from the game, not from the picture

Written as fractions of the image, since the generator picks the resolution:

- **16:9.** The world is 1536x864 and the camera frames all of it at one zoom. The current
  board is 1672x941, which is 16:9 exactly. Crop to it if the generator returns 3:2.
- **The road is 5% of the image width**, edge to edge (80px of 1536), and holds that width
  along its whole length. `Game.ROAD_HALF` is a single constant; a widening plaza is a place
  where enemies walk off the road.
- **The road runs about 2.1 image widths in total** (3199px on a 1536 world).
  `Balance.BASE_SPEED_*` and `BASE_COUNT_*` are tied to the road length and nothing else
  reads it, so a much shorter or longer road silently re-paces the whole game.
  **The current road already satisfies both**, which is the strongest practical argument for
  keeping its layout: a redesigned route re-opens the pacing question for nothing.
- **Grass shoulders at least 10% of the image width beyond each kerb** — 150px on a 1536
  world. A tower centre must sit `ROAD_KEEPOUT` = **83.2px** from the road centre-line,
  which is 43.2px beyond the kerb, and its footprint reaches `TOWER_RADIUS` = 30px past
  that: **~73px of shoulder buys one row of towers**. A second row is a `PAD_PITCH` hex row
  further out (~97px), so two rows want ~170px. 150px is one comfortable row and the start
  of a second — treat it as the floor, and more is always better.
- **WHERE THE ROAD ENTERS AND LEAVES is a rule.** Both halves were got wrong on the first
  glacier and both were found by playing it, not by measuring the picture:
  - **The entry must sit at least a fifth of the way down.** The HUD bar covers the world's
    top 48px and a creep is drawn `radius * 2.6` tall ABOVE its feet, so a boss (radius 38,
    99px) standing on a road at y=61 is entirely behind the bar and only its feet show. Ask
    for the road to meet the edge about a QUARTER of the way down and it clears with room.
  - **The exit belongs at the BOTTOM edge, not the right one, and it is not a building.**
    The tower palette is a column down the top of the right edge (world y 58-502 of 864), so
    a road that leaves on the right risks its last stretch running behind it — a leak nobody
    sees. The bottom edge is clear apart from the pause and speed buttons in its left corner,
    so keep the exit out of the left 14% too. `--dump-board` prints `road under UI`; a new
    board should read 0%. And the
    road should simply run off the frame: a painted gatehouse reads as a door the creeps are
    walking into, and the game draws no goal marker of its own to argue with.
- **Three areas are covered by UI.** The HUD bar covers the top 48px; the tower palette is a
  column over world x 1426-1526, y 58-502 (the top-right corner); the Pause and speed buttons
  cover world x 14-216, y 797-854 (the bottom-left corner). The palette and the buttons eat
  clicks, so nothing can be built under them either. Keep the road, and anything the player
  must see, out of all three, and fill them with scenery. Everything else — including the
  right edge below the palette — is board. (Until the palette became a column it was a
  panel down the whole right 16%, and older briefs below were written against that.)
- **Broad curves, not switchbacks.** This one is already settled by keeping the layout, and
  is recorded for the day someone proposes a new route. Folding the path tighter was measured on the ported
  spiral and it makes coverage *worse*: the legs end up close enough that one tower circle
  catches several of them, and the tight folds leave no buildable ground between.

## The template

```text
[Attach FIVE files, in this order:
   1. C:\Users\alica\OneDrive\Belgeler\GitHub\godot-tower-defense-\godottowerdefense\assets\art\towers\_source_fire.png
      ^ the buildings that must stand on this board
   2. C:\Users\alica\OneDrive\Belgeler\GitHub\godot-tower-defense-\godottowerdefense\assets\art\towers\_source_water.png
      ^ ditto
   3. C:\Users\alica\OneDrive\Belgeler\GitHub\godot-tower-defense-\godottowerdefense\assets\art\board_source.png
      ^ the light and palette to match
   4. C:\Users\alica\OneDrive\Belgeler\GitHub\godot-tower-defense-\godottowerdefense\assets\art\maps\winding_forest_close_v1.png
      ^ the board being replaced, LAYOUT ONLY
   5. the same board as 4, with the wanted open ground drawn on it in yellow - see below]

Images 1 and 2 are towers the player will place on the board you are about to paint. Images
3, 4 and 5 are boards. Paint a REPLACEMENT board for a 2D tower defense.

THE TOWERS COME FIRST. Images 1 and 2 were painted before this board and cannot be
repainted, so the board must join THEM. Study them: the height of the camera looking at
them, the direction and softness of the light on their stonework, and how bright and how
saturated that stonework is. The board you paint has to look like the ground those exact
buildings are standing on.

Image 3 is the board those towers were originally painted against. Take its LIGHT and its
PALETTE — bright open daylight, warm sunlit grass, muted painterly colour.

Image 4 is the board being replaced. Take from it ONLY the kind of place it is: the same
world, the same conifer forest, the same stone road. Do NOT take its light, its darkness,
or its camera — those are the three things being changed. It is dimmer than the towers and
is painted looking straight down, and both are faults this replacement exists to fix.

Image 5 is image 4 with YELLOW OUTLINES drawn on it by hand. Everything inside a yellow
outline is ground where the player needs to place a building, and in image 4 it is full of
trees, rocks and undergrowth. In your painting, all of that ground is FLAT EMPTY GRASS with
nothing standing on it. Read image 5 as an instruction about how much open ground is
wanted and where it sits relative to the road — a wide apron on both sides plus the whole
inside of every bend — and not as an exact shape to trace, since your road will be drawn
at a different camera angle from image 4's.
DO NOT DRAW THE YELLOW LINES. They are annotation and must not appear anywhere in your
painting, in any colour, as an outline, a path, a border or a glow.

Aspect ratio 16:9, landscape, no transparency, no border, no frame, no vignette, no text,
no watermark, no UI, no characters, no towers, no buildings.

WHAT TO KEEP, AND WHAT TO CHANGE:

This is NOT a new map. It is image 4's map, with three faults corrected. Go through the
list below literally: anything not named under CHANGE is under KEEP by default, and if you
are unsure about a feature, KEEP IT.

KEEP — these are already correct and must survive into your painting:
- The road's entire route (see the next section).
- The WATERFALL and its river down the LEFT EDGE of image 4, with the wet dark cliffs
  around it. It is a landmark of this level. Keep it in the same place, at the same size,
  the same shape, the same colour. Do not shrink it, do not move it, do not replace it
  with a pond or a stream, and do not delete it.
- The dark cliff walls and stone columns that frame the picture at its edges.
- The conifer forest as the surrounding: same kind of tree, same dark blue-green.
- The world: same place, same season, same hour, same overall composition.

CHANGE — exactly three things, and nothing else:
1. THE GROUND BESIDE THE ROAD opens up. Where image 4 packs trees, rocks and undergrowth
   right up to the kerb, your painting has wide empty grass. This is the apron, below.
2. THE LIGHT gets brighter. Image 4 is dim; the open grass must be sunlit.
3. THE CAMERA comes down off vertical, to a three-quarter view. See THE CAMERA below.

Image 4 is a dense forest with the road cut through it, so there is almost nowhere flat to
stand. Your painting is the SAME PLACE — same road, same waterfall, same cliffs, same
forest — on a brighter day, seen from a lower angle, with the ground beside the road
cleared open.

THE ROAD — DO NOT REDESIGN IT:
- The road in image 4 is the game's real level layout. It is already built and cannot be
  changed, so COPY IT: the same sequence of bends in the same order, curving the same
  directions, entering the picture at the same edge and leaving at the same edge, and
  crossing the picture at the same proportions of the width and height.
- Do NOT invent a new route. Do not add a bend, remove a bend, straighten one, deepen one,
  mirror the layout, rotate it, or shift where it enters and leaves.
- The ONE change to the road is the one the camera forces. Seen from a three-quarter view
  instead of from straight overhead, the whole scene compresses vertically, so the bends
  get shallower top-to-bottom while holding their left-to-right positions. That is
  expected and correct. Nothing else about the route changes.
- Same constant width along its whole length, about 5% of the image width, edge to edge.
  No widening, no plaza, no crossroads, no fork, no side path.
- Same pale grey-tan cobblestone — light, slightly cool, clearly greyer than the grass.
  NOT mossy, NOT earth-brown, NOT overgrown.
- It stays fully visible for its whole length: nothing overlaps it, no tree crown or cliff
  in front of it hides a stretch, no bridge, no arch, and it never crosses itself.

THE BUILDING APRON — the single most important requirement in this brief:

There is a continuous APRON of completely empty grass around the road. It is one connected
region, and it has two parts that must join into each other:
- A band following the road down BOTH sides for its entire length, at least 10% of the
  image width wide on each side beyond the road's edge. It never pinches shut and is never
  interrupted.
- The whole INTERIOR of every bend. Where the road curves back on itself, the ground it
  encloses is open grass all the way across — not a clearing with a tree in the middle of
  it, not a ring of grass around a stand of trees. Empty.

NOTHING STANDS IN THE APRON. Not one tree. Not one rock, boulder, stone outcrop, basalt
column or cliff edge. No stumps, no fallen logs, no ruins, no fences, no hedges, no
signposts, no bushes, no shrubs, no tall grass, no bracken, no scrub, no reeds, no water.
If an object would cast its own shadow, it does not belong here. This is the requirement
the previous board failed hardest and it is not a matter of degree — a single boulder in
the middle of an otherwise open pocket removes that pocket from play.

WHAT THE APRON LOOKS LIKE:
- Flat, open, mown lawn. WARM YELLOW-GREEN, sunlit, evenly lit corner to corner, carrying
  almost no blue.
- Its texture is CALM. A few faint mown bands and a light scatter of tiny flowers lying
  flat in the grass are welcome. Dense flower clumps, wildflower beds, patches of
  blue-purple blooms, leaf litter, twigs and speckled undergrowth are NOT — they read as
  clutter at a distance and the game treats a broken-up meadow as unbuildable ground.
- Do NOT cast large shadows across it. No cloud shadows, no long tree shadows reaching in
  from the treeline, no dark corners, no darkened edges, no god rays.
- Beyond the apron the meadow may open into wider lawns and gentle rises. More open ground
  anywhere is always better than less.

THE FOREST AND THE CLIFFS — they are not deleted, they are PUSHED BACK:
- Image 4's forest and cliffs stay in the painting. They move OUT of the apron and mass at
  the outer edges of the picture instead — a rim around the valley, a treeline on the far
  side, groves in the corners, cliff walls along the borders. The picture must still read
  as a forest valley, not as a bare field.
- Same trees as image 4: dark, blue-green conifers, reading much darker and cooler than
  the grass. Same dark stone for the cliffs and columns.
- What changes is only WHERE they are. Nothing vertical stands inside the apron; all of it
  lives outside it.
- The top 6%, a column down the right 7% of the image to just past half its height, and the bottom-left corner (the left 14% of the bottom 8%) are covered by interface in the game: those
  areas should carry dense forest, cliffs or distant hills, and nothing the player would
  need to see.

WATER — KEEP THE WATERFALL:
- Image 4's waterfall and river run down its LEFT EDGE. Keep them, in the same place, at
  the same size and shape. They are a landmark of this level and removing or shrinking
  them is a failure of this brief, not a simplification of it.
- Keep the water clearly BLUE and distinctly bluer than anything else in the picture —
  the game finds the water by its blue and animates it, so grey or green water stops
  flowing.
- Do not ADD new water anywhere: no new ponds, no new streams, no puddles in the meadow.
  Water is as unbuildable as a tree, so a stream crossing the apron costs exactly what a
  treeline would.
- Water must not touch the road or the apron, must not cross the road, and must not gain
  a bridge or a ford. In image 4 it already does none of these; keep it that way.

THE CAMERA — the requirement image 4 fails, so read this twice:
- The ground is seen from a THREE-QUARTER view, looking down at it at an angle, the same
  way the towers in images 1 and 2 are seen. Not from straight overhead.
- Concretely, and this is the test: where the road runs LEFT-TO-RIGHT across the picture it
  must be drawn about HALF as wide as where it runs TOP-TO-BOTTOM. A road crossing the view
  is foreshortened; a road running away from the viewer is not.
- Everything standing on the ground obeys the same view. Trees show their sides and not
  just their tops. Rocks and cliffs show a face. Nothing is seen from directly above.

MATCH ON:
- Light. Bright open daylight, the same direction and softness as the light on the towers
  in images 1 and 2 — from the upper left, soft-edged, no hard cast shadows.
- Value. The open sunlit grass must be as BRIGHT as the grass in image 3. This is the most
  common failure: a moody, dim forest floor looks better on its own and makes every
  building placed on it look pasted on. Err light.
- Palette and saturation. Muted and painterly, warm — image 3's register, not image 4's.
- Rendering. Soft painted edges, no hard black outline, the same detail density.
```

## Variant: re-rendering a board that is already right except for the camera

`winding_forest_cleared_v7_graded.png` has the layout, the open apron, the waterfall and —
after `grade_board.py` — the colour, and fails only the camera. Asking for a fresh board
would put all four back at risk to fix one.

### Attempt 1 failed, and how it failed is the useful part

The first prompt described the camera as a RATIO: "where the road runs left-to-right it must
be drawn about half as wide as where it runs top-to-bottom", plus an explicit ban on
convergence. The result measured `squash 1.000` — no change at all.

What the generator did instead was redraw the TREES more three-dimensionally: conifers came
back showing trunks and flanks where before they were crowns seen from above. So it did
engage with "lower camera" — it just applied it to the objects and left the GROUND PLANE in
plan view. It also cost 33% of the road's area and moved 33% of it off the old route.

**The lesson: an image generator has no model of projection.** It pattern-matches style, so
a geometric instruction ("compress this axis by half") has nothing to attach to, while a
style name it has seen ten thousand times does. Do not describe the transform. Name the
look, and describe what is VISIBLE at that look.

### The prompt

```text
[Attach THREE files, in this order:
   1. C:\Users\alica\OneDrive\Belgeler\GitHub\godot-tower-defense-\godottowerdefense\assets\art\maps\winding_forest_cleared_v7_graded.png
      ^ the scene to re-render
   2. C:\Users\alica\OneDrive\Belgeler\GitHub\godot-tower-defense-\godottowerdefense\assets\art\towers\_source_fire.png
      ^ the view to match
   3. C:\Users\alica\OneDrive\Belgeler\GitHub\godot-tower-defense-\godottowerdefense\assets\art\towers\_source_water.png
      ^ ditto]

Image 1 is a game map drawn in FLAT TOP-DOWN view, straight down from above like a
satellite photo. Redraw the same place as a CLASSIC ISOMETRIC REAL-TIME-STRATEGY MAP - the
tilted three-quarter overhead view used by Warcraft III, Age of Empires and Diablo, where
you look down on the terrain at an angle and can see the fronts of things, not only their
tops.

Images 2 and 3 are buildings that will be placed on this map. They are already drawn at the
correct viewing angle. Your map must be drawn from THAT angle, so that one of those
buildings standing on your ground would look like it belongs there rather than pasted on.

WHAT CHANGES - the viewing angle, and what that makes visible:
- The ground is a surface receding away from the viewer, not a flat plan seen from directly
  overhead. Meadows read as ground you could walk across toward the horizon.
- The cliff walls and rock columns show their FRONT FACES, tall and vertical, not their
  tops. Their height becomes visible.
- The waterfall is seen from in front, falling down a visible rock face, not looked into
  from above.
- The road lies flat on that receding ground, so its bends read as loops lying away from
  you. It becomes shallower and wider-looking top-to-bottom than in image 1.
- Trees stand up from the ground with visible trunks and full cone silhouettes.

WHAT MUST NOT CHANGE:
- The road's ROUTE: the same sequence of bends in the same order, curving the same
  directions, entering and leaving at the same edges, one continuous unbroken ribbon of the
  same pale grey-tan cobblestone at a constant width. It is the same road, seen from a
  different angle.
- The colours. The grass is the exact yellow-green of image 1. Do not darken it, do not
  saturate it, do not shift it toward blue or toward emerald.
- The waterfall stays on the LEFT edge.
- The open grass stays open: the wide clear meadow of image 1 has no trees, rocks, boulders
  or bushes growing back into it.
- The forest and cliffs stay massed at the edges of the picture, framing the meadow.
- 16:9 landscape, the ground filling the whole frame.

CRITICAL - it is a GAME MAP, not a landscape painting:
- NO horizon line, NO sky, NO clouds, NO distant mountains. Ground from edge to edge.
- Do NOT make things smaller because they are higher up the picture. A tree at the top of
  the image is the same size as the same tree at the bottom. Parallel lines stay parallel.
- The road is the same width at the top of the picture as at the bottom.
- No text, no watermark, no UI, no characters, no towers, no buildings, no border, no
  vignette.
```

### Reading the result

`python tools/art_match.py <new> --against <the graded board>`

- **squash** is the whole point: 0.35-0.65 is a win, 1.000 means it failed again.
- **road held** WILL drop and that is expected this time — a tilt moves every waypoint, so
  budget for a re-trace and start from the old control points rather than hunting new ones.
- **value / hue** may drift; that costs nothing, `grade_board.py` puts any board back on
  target in one run.
- Then check by hand what the tool cannot: the road's width at the TOP of the image against
  the BOTTOM. Equal means oblique and usable. Narrower at the top means the generator gave
  true perspective, and the board is unusable whatever else it got right, because the engine
  scales no sprite by depth (see "The projection must be OBLIQUE" above).

**If this attempt also returns squash 1.000, stop.** Two failures on two different prompt
strategies is enough evidence that this transform is not available through a generator, and
the remaining routes are repainting the 85 tower sprites or accepting the mismatch.

## After the image lands

0. **Measure it before wiring it in.** `python tools/art_match.py <the-new-board.png>` needs
   nothing but the file, and it answers the three questions this repaint exists for:

   | Check | Target | Winding today |
   |---|---|---|
   | open ground in the 70-300px band | ≥ 80% | **22.6%** |
   | open ground luminance | ≥ 97 (the roster's own board reads 106) | 73.3 |
   | tower masonry blue vs open-ground blue | within 15 | 21 over |
   | ground squash | 0.50 ± 0.15 | 1.000 |

   **Do this first every time.** Connecting a board is hours of work — hand-tracing the road
   into control points, two masks, a `use_board` branch — and re-running the prompt is
   minutes. A board that fails here fails after all that work too, and by then the sunk cost
   argues for keeping it.

1. **Check the colour type before anything else.** A sheet saved without alpha is fine for a
   board, but a 3:2 canvas is not — crop to 16:9 first, at the top, since the top strip is
   under the HUD.
2. Drop it in `assets/art/maps/<name>.png`, run Godot once with `--import`, then flip
   `mipmaps/generate` to `true` in its `.import` (a new PNG arrives with it false — see
   CLAUDE.md's known traps).
3. `python tools/build_mask.py assets/art/maps/<name>.png` and
   `python tools/water_mask.py assets/art/maps/<name>.png assets/art/maps/<name>_water.png`.
4. Read the road's control points off the painting into a new `Game.<NAME>_PATH`, add a
   `use_board` branch, a `BUILD_MASKS` row and the two `map.gd` consts.
5. **Turn on `map.gd`'s `show_road`** and look. It draws the traced line back over the
   painting and it is the only check that catches enemies walking beside the road.
6. `--dump-board` for the numbers and `--shot` for the picture. The target is the shoulder
   requirement actually paying off: buildable spots well above 51, and both Water and Fire
   reaching more than 90% of the road.
7. **Move `Game.GROUND_SQUASH` to whatever `art_match.py` measured on the new board.** The
   engine draws every shadow, pad and ground glow at that number, and it is currently 0.45
   against a board painted at 1.00 — a debt inherited from the old board, not a choice. The
   prompt asks for 0.50 so the two should already agree, but measure rather than assume.
8. **Re-check the pad count against the economy.** `Balance.TIER_COSTS` and `FUSION_COSTS`
   were sized so a full board absorbs ~85% of a run's ~41,300 gold, and that arithmetic
   assumes 12 pads. A board that delivers on its shoulders will move that number a long way.
   See CLAUDE.md, "More open ground does not mean more gold".

## What the first attempt will get wrong

Recorded so the second attempt does not have to rediscover them — these are the failure
modes the constraints above are written against, and a generator drifts back to all of them
when the prompt is loosened:

- **Redesigning the road.** The most expensive failure and the easiest to wave through,
  because a fresh route looks like a better picture and reads as the generator doing its
  job. It is not: the layout is built, traced and balanced, and a new one throws away
  `Game.WINDING_PATH` and re-opens the pacing constants. Lay the result over image 4 and
  check the bends are the same bends in the same order before looking at anything else.
- **Trees creeping back to the roadside**, because a road through a wood is the more
  beautiful picture. It is also the picture that has nowhere to build.
- **The apron surviving as a thin verge.** Asking for open ground reliably produces a metre
  of grass at the kerb and forest immediately behind it, which measures almost the same as
  no apron at all — a tower has to stand 83px off the centre-line before it may be placed
  and its footprint reaches 30px past that. Check the band figure, not the impression.
- **One object left in each clearing.** A generator that has cleared a pocket will often
  centre a hero boulder or a single picturesque pine in it, because an empty field looks
  unfinished. Every one of those deletes the pocket. This is why the brief bans objects by
  name rather than asking for "open" ground.
- **Flower beds instead of trees.** The obvious way to make a cleared meadow interesting is
  to fill it with blooms, and dense clumps fail `build_mask.py`'s block test exactly as
  canopy does. Flowers must lie flat and stay sparse.
- **Dramatic lighting** — a shaft of light on the road, shadow everywhere else. The mask
  reads that shadow as forest and deletes the map.
- **A tight, decorative spiral or hairpin**, which looks like a game board and measures
  worse than a lazy curve.
- **A stream crossing the road**, which is the one water feature that both blocks placement
  at the crossing and needs a bridge the tracer cannot see under.
- **Drifting back to straight overhead.** A top-down board is the easier picture — nothing
  occludes anything, every meadow is fully visible — and it is what the previous prompt got
  when it asked for the camera in words. This is the one failure that cannot be repaired
  later by grading, recolouring or any code change, so check it first with `art_match.py`
  and reject on it alone.
- **Matching image 4 instead of images 1-3.** Four attachments and three of them are there
  to be matched while the fourth is there to be departed from, which is an unusual thing to
  ask and the first thing a generator smooths over. The tell is a dim board: if the new
  grass is no brighter than the old, the reference was taken from the wrong image.

---

# Generating a NEW map (not a replacement)

Everything above is about REPLACING the winding board, where the road is already built and
the brief's hardest job is stopping the generator redesigning it. A new map is a different
and much easier problem: **there is no route to preserve, so the failure mode that section
spends most of its length guarding against does not exist.** Any road the generator returns
is acceptable as long as it satisfies the constraints below, and it is then read off the
painting by hand in the usual way.

## What the roster is missing, measured

All three shipped boards fail `art_match.py`'s band test, and they cluster within nine build
spots of each other:

| | open band (want 80%) | build spots | coverage, best 1 tower |
|---|---|---|---|
| Winding Forest | 62% | 33 | 25-41% |
| Twin Falls | 74% | 29 | 31-48% |
| Spiral Arena | 78% | 24 | 23-39% |

So the gap is not another middling board — it is an **OPEN, high-capacity** one. That is also
the cheapest kind to paint, because the wide empty apron the other three fail to provide is
the default state of a meadow rather than something that has to be carved out of a forest.

The first new map is therefore **Long Meadow**: one long road with lazy curves through wide
open grass, aiming at 60+ build spots. It is the breadth pole of the roster — many cheap
towers each watching its own stretch, with depth as a trap.

**To generate a DIFFERENT map concept, swap only the THE ROAD section.** Everything else in
the prompt is the engine's requirements and does not change between maps.

## The prompt

```text
[Attach THREE files, in this order:
   1. C:\Users\alica\OneDrive\Belgeler\GitHub\godot-tower-defense-\godottowerdefense\assets\art\towers\_source_fire.png
      ^ buildings that will stand on this board - match their camera and their light
   2. C:\Users\alica\OneDrive\Belgeler\GitHub\godot-tower-defense-\godottowerdefense\assets\art\towers\_source_water.png
      ^ ditto
   3. C:\Users\alica\OneDrive\Belgeler\GitHub\godot-tower-defense-\godottowerdefense\assets\art\board_source.png
      ^ an existing map in the same game - take its LIGHT and PALETTE only, NOT its layout]

Paint a game map for a 2D tower defense. Images 1 and 2 are buildings the player will place
on it; image 3 is an existing map in the same game.

THE TOWERS COME FIRST. Images 1 and 2 were painted before this map and cannot be repainted,
so the ground must join THEM. Study them: how high the camera sits, the direction and
softness of the light on their stonework, and how bright and how saturated that stonework
is. Your painting has to look like the ground those exact buildings are standing on.

Image 3 is there for LIGHT and PALETTE ONLY - bright open daylight, warm sunlit grass, muted
painterly colour. Do NOT copy its layout: its road is a spiral and yours is not.

Aspect ratio 16:9, landscape. No transparency, no border, no frame, no vignette, no text,
no watermark, no UI, no characters, no towers, no buildings.

THE PLACE:
A wide, open, sunlit meadow valley. Mostly grass. Conifer forest, rock outcrops and low
cliffs frame it around the EDGES of the picture only. This is a broad field with a road
across it, NOT a road cut through a wood - if the picture reads as "forest", it is wrong.

THE ROAD:
- One continuous stone road crossing the whole picture, entering at the LEFT edge about a
  third of the way down and ending at a small stone gatehouse about three quarters of the
  way across and low in the frame.
- Three or four LONG, LAZY curves - wide sweeping bends, generously far apart from one
  another, like a country lane. NOT a spiral, NOT switchbacks, NOT hairpins, NOT a zigzag,
  and it never doubles back to run close alongside itself.
- Constant width for its whole length, about 5% of the image width edge to edge. No
  widening, no plaza, no crossroads, no fork, no side path, no gate across it.
- It never crosses itself, never passes under anything, and no tree crown, cliff or bridge
  hides any stretch of it. Every part of it is visible from above.
- PALE GREY-TAN COBBLESTONE: light, slightly cool, clearly greyer and cooler than the
  grass. NOT mossy, NOT earth-brown, NOT dirt, NOT sandy, NOT overgrown.

THE OPEN GROUND - the single most important requirement in this brief:
- The grass on BOTH SIDES of the road, for its entire length, is completely EMPTY for a wide
  band - at least 15% of the image width beyond each kerb. The whole inside of every bend is
  open too, all the way across.
- NOTHING STANDS IN IT. Not one tree, rock, boulder, stump, fallen log, bush, shrub, hedge,
  fence, ruin, signpost, reed or patch of tall grass. If an object would cast its own shadow,
  it does not belong there. A single picturesque boulder in the middle of an otherwise open
  pocket ruins that pocket.
- Beyond that band the meadow keeps opening into wider lawns and gentle rises. More open
  ground anywhere is always better than less. Aim for most of the picture being open grass.

WHAT THE GRASS LOOKS LIKE - read this twice, a program measures it:
- Flat, open, mown lawn. WARM YELLOW-GREEN and SUNLIT, carrying almost no blue at all.
- Lit EVENLY from corner to corner. NO cloud shadows, NO long tree shadows reaching in from
  the treeline, NO dark corners, NO darkened edges, NO vignette, NO god rays, NO dramatic
  pools of light. A shadow across the meadow deletes the meadow.
- Its texture is CALM. A few faint mown bands and a light scatter of tiny flowers lying flat
  in the grass are welcome. Dense flower clumps, wildflower beds, blue-purple blooms, leaf
  litter, twigs and speckled undergrowth are NOT - they read as clutter at a distance.

THE FOREST AND CLIFFS - at the edges, not in the field:
- Dark, blue-green conifers, reading much darker and cooler than the grass. Dark stone for
  the cliffs and outcrops. They mass at the outer rim of the picture: a treeline on the far
  side, groves in the corners, cliff walls along the borders.
- The top 6%, a column down the right 7% of the image to just past half its height, and the bottom-left corner (the left 14% of the bottom 8%) are covered by interface in the game. Fill those
  areas with dense forest, cliffs or distant hills and put nothing there the player needs to
  see. Keep the road and the gatehouse out of all three.

WATER:
- One clearly blue pond or short stream, at an EDGE of the picture, away from the road.
- Keep it distinctly BLUER than anything else in the painting - the game finds water by its
  blue and animates it, so grey or green water will not flow.
- It must NOT touch the road or the open band beside it, must not cross the road, and gets no
  bridge or ford. Do not scatter extra puddles through the meadow: water is as unbuildable
  as a tree.

THE CAMERA - the requirement most maps fail, so read this twice:
- The ground is seen from a THREE-QUARTER view, looking down at it at an angle, the same way
  the buildings in images 1 and 2 are seen. NOT from straight overhead.
- Concretely, and this is the test: where the road runs LEFT-TO-RIGHT across the picture it
  must be drawn about HALF as wide as where it runs TOP-TO-BOTTOM.
- Everything standing on the ground obeys the same view. Trees show their sides and their
  trunks, not only their tops. Rocks and cliffs show a face.

THE PROJECTION MUST BE OBLIQUE, NOT PERSPECTIVE - this one comes from the engine:
- Compress the view uniformly. The top of the picture is NOT further away than the bottom.
- Do NOT converge parallel lines. Do NOT make distant things smaller: a tree at the top of
  the image is the same size as the same tree at the bottom.
- The road is the SAME WIDTH at the top of the picture as at the bottom.
- NO horizon line, NO sky, NO clouds, NO distant mountain range. Ground from edge to edge.

MATCH ON:
- Light: bright open daylight, the same direction and softness as the light on the buildings
  in images 1 and 2 - from the upper left, soft-edged, no hard cast shadows.
- Value: the open sunlit grass must be as BRIGHT as the grass in image 3. This is the most
  common failure - a moody, dim field looks better on its own and makes every building placed
  on it look pasted on. Err light.
- Palette and saturation: muted and painterly, warm.
- Rendering: soft painted edges, no hard black outline, the same detail density.
```

## Reading the result

Same order as the replacement flow above, and step 0 is still the whole point: **measure
before wiring anything in**, because connecting a board is hours of work and re-running the
prompt is minutes.

```
python tools/art_match.py <the-new-board.png>
```

| Check | Target | Why it is worth rejecting on |
|---|---|---|
| open ground in the 70-300px band | **≥ 80%** | this map exists for this number; below ~70% it is another middling board |
| ground squash | 0.50 ± 0.15 | 1.000 is straight overhead, and no colour work fixes it |
| open ground luminance | ≥ 97 | below this the towers read as stickers on the board |
| road width top vs bottom | equal, by eye | unequal means true perspective, which the engine cannot draw at all |

Then the usual: crop to 16:9, drop into `assets/art/maps/`, `--import`, flip
`mipmaps/generate` to `true`, run `build_mask.py` and `water_mask.py`, read the road off the
painting into a new `Game.<NAME>_PATH`, add the `Game.BOARDS` row (including a
`board_thumb.py` thumbnail and a `road_len` measured by `--dump-board`), check the trace with
`map.gd`'s `show_road`, then `--dump-board` and `--play-sim`.

## Other biomes: ice, ash, desert

The prompt above paints a green meadow. Three of its blocks are what make it green, and
swapping just those three gives a different world on the same rules:

**THE PLACE** · **WHAT THE GRASS LOOKS LIKE** · **THE FOREST AND CLIFFS** · **WATER**

Everything else — the camera, the oblique projection, the road's geometry, the open band,
the UI strips, MATCH ON — is the engine's requirements and must be carried across unchanged.

### Two things that break on a non-green board

**1. The build mask stops working, silently.** `build_mask.py`'s default test is
`(g - b) > 35`, which is "warm yellow-green". Measured: sunlit snow (235, 240, 248) gives
`g-b = -8`; an ash plain (105, 98, 92) gives `6`. Both are far under the threshold, so the
tool writes a black mask, reports 0% open ground, and the board arrives with nowhere to
build. Use the declared-ground mode instead:

```
python tools/build_mask.py <board.png> --ground=R,G,B --tol=N
```

Eyedrop `R,G,B` off the finished painting's open ground; the starting points below are
estimates, not measurements. Desert is the exception that needs none of this — sand measures
`g-b = 48` and passes the default test by accident.

**2. The road can vanish into the ground.** The road is read off the painting BY HAND (and
`trace_road.py`, for a spiral, hunts pale grey-tan cobble specifically). A pale stone road on
snow, or a grey road on grey ash, is not a style choice — it is a road nobody can trace. Each
brief below therefore fixes the road's value AGAINST its ground, and that contrast is not
negotiable.

### Alaska — ice

```text
THE PLACE:
A wide, open, snow-covered valley floor under bright winter sun. Mostly flat, untouched
snowfield. Dark evergreen spruce, frozen rock outcrops and low ice-crusted cliffs frame it
around the EDGES of the picture only. A broad snowfield with a road across it, NOT a road
cut through a forest.

WHAT THE GROUND LOOKS LIKE - read this twice, a program measures it:
- Flat, open, unbroken SNOW. Bright, clean, sunlit white with cool blue-grey shading in the
  gentlest dips. It is one continuous surface with no objects standing in it.
- Lit EVENLY corner to corner. NO long blue tree shadows reaching in from the treeline, NO
  cloud shadows, NO dark corners, NO vignette, NO dramatic pools of light.
- Its texture is CALM: soft drifts and faint wind ripples only. No rocks poking through, no
  scattered stones, no tussocks of dead grass, no footprints, no debris.

THE ROAD:
- DARK, WET, NEARLY BLACK STONE, swept clear of snow - a dark ribbon crossing a white field.
  It must read as the DARKEST thing in the open part of the picture. It is NOT pale, NOT
  grey-white, NOT snow-covered, NOT icy, and it never blends into the snow.
- Low banks of ploughed snow along its edges are welcome, and must not spread into the wide
  open band beyond them.

THE TREES AND CLIFFS - at the edges, not in the field:
- Dark blue-green spruce heavy with snow, and dark frozen rock. They read much DARKER than
  the snowfield. They mass at the outer rim: a treeline on the far side, groves in the
  corners, ice-crusted cliff walls along the borders.

WATER:
- One clearly BLUE patch of open meltwater or blue glacial ice at an EDGE of the picture,
  away from the road. It must be distinctly BLUER than the snow - the game finds water by
  its blue, and white ice will not read as water at all.
```

Start from `--ground=232,238,247 --tol=55`. The tolerance matters more here than anywhere:
too wide and it swallows the pale ice cliffs, too tight and shadowed snow stops being
buildable.

### Attempt 1 came back as the meadow painted white, and why

`sunlit_snowfield_v1.png` and `sunlit_meadow_v1.png` are the SAME PAINTING in two palettes:
the same road route, the same tree placement, the same basalt columns, the same gatehouse
position, the same water in the same corner. Laid side by side they are one map with a
filter on it.

That is the brief's fault, not the generator's. The ice version above swaps four blocks and
keeps everything structural: the same road paragraph, the same "conifer forest frames the
edges", the same composition. Given identical structure and a new palette, a recolour is the
only thing left to vary.

**Two lessons, and the second is the useful one:**

1. **The trees are the tell.** Snow-capped conifers over snow-capped basalt columns read as
   *our forest map in winter*, because they are literally the forest map's vocabulary. A
   different world needs different objects in it, not the same objects repainted.
2. **A biome is a LANDFORM, not a colour.** "Snowy field ringed by trees" is the meadow.
   "A glacier" is a different shape of ground with its own structures — crevasses, seracs,
   moraine, meltwater, ice walls — and those structures are what make it unmistakable.

There is a third problem both images share: **the middle is a void.** The brief's "nothing
stands in the open band" plus "aim for most of the picture being open" produced a large
featureless centre. It measures well and looks unfinished. The fix is not fewer open areas —
it is surface detail that lies FLAT: `build_mask` refuses things by colour and by how much
of an 8px block matches the ground, so pattern painted into the ground at a near value stays
buildable, while anything that stands up and casts a shadow correctly blocks. Flow lines,
ripples, drift patterns and faint dust are all free.

### The camera: stop asking

Every board this repo has ever measured comes back at squash **1.000**, straight down —
`board_source`, the winding board, the S board, and now both new ones. Two documented prompt
strategies failed at it (the ratio phrasing and the "classic isometric RTS map" phrasing) and
this was the third. The target of 0.50 has no working example behind it and never has.

So the ice brief below **asks for top-down and says so**, and spends the words it saves on
the landform instead. All boards agreeing with each other matters more than any of them
agreeing with the tower sheets, and they already all agree at 1.000.

### Attempt 2: the glacier, as a landform

The design goal changed with it. The meadow already gives the roster its open, high-capacity
map. The glacier is the opposite pole and the ICE ITSELF supplies it: crevasse fields and
moraine stripes cut the buildable surface into **pockets**, so placement becomes a puzzle of
which island covers which stretch of road, rather than a continuous wall. The art and the
gameplay want the same picture, which is the point.

```text
[Attach THREE files, in this order:
   1. C:\Users\alica\OneDrive\Belgeler\GitHub\godot-tower-defense-\godottowerdefense\assets\art\towers\_source_fire.png
      ^ buildings that will stand on this map - match their light and their painting style
   2. C:\Users\alica\OneDrive\Belgeler\GitHub\godot-tower-defense-\godottowerdefense\assets\art\towers\_source_water.png
      ^ ditto
   3. C:\Users\alica\OneDrive\Belgeler\GitHub\godot-tower-defense-\godottowerdefense\assets\art\board_source.png
      ^ an existing map in the same game - match its RENDERING STYLE and its CAMERA. Nothing else.]

Paint a game map for a 2D tower defense, seen from directly above.

Image 3 is an existing map in the same game. Match its rendering: the same painterly finish,
the same level of detail, the same bright even daylight, and THE SAME CAMERA - looked at
from straight overhead, flat, no horizon, no sky, ground filling the whole frame. Do NOT
copy anything else from it. Images 1 and 2 are buildings that will be placed on your map;
match the direction and softness of the light on their stonework.

Aspect ratio 16:9, landscape. No transparency, no border, no vignette, no text, no
watermark, no UI, no characters, no towers, no buildings.

THE PLACE - this is the whole brief, read it before anything else:

The surface of a GREAT GLACIER, seen from above. Not a snowy field. Not a forest in winter.
A slow river of ancient ice, hundreds of metres thick, filling the frame from edge to edge.

THERE ARE NO TREES ON THIS MAP. No conifers, no spruce, no pines, no bushes, no grass, no
soil, no meadow, not one. Anything green is wrong. If a tree appears anywhere in the picture
the map has failed.

WHAT THE ICE LOOKS LIKE:
- The main surface is packed snow over ice: bright, clean, sunlit, near-white with the
  faintest cool blue in its hollows. This is the ground the player builds on and most of the
  picture is made of it.
- It is NOT featureless. Long, gentle FLOW LINES curve across it - pale bands showing which
  way the ice is moving, like the grain in a slow river - together with soft drift ripples
  and faint scour marks. All of this is painted FLAT INTO the surface: it is texture, not
  objects, and nothing in it stands up or casts a shadow.
- Keep the ICE SURFACE ITSELF pale, near-white. Save saturated blue for the meltwater and
  the crevasse depths only.

WHAT BREAKS THE ICE UP - these are the map's real features:
- CREVASSE FIELDS: groups of long parallel splits in the ice, following the flow lines,
  their depths dark and shadowed. Several across the map, some at the edges and two or three
  reaching into the middle. Paint their insides DARK and desaturated - deep blue-black
  shadow, NOT glowing cyan.
- SERACS: zones where the ice has buckled into a chaos of standing blocks and towers of ice,
  casting real shadows. Two or three such zones, at the edges and in the corners.
- MORAINE: long stripes of dark grey-brown rock rubble carried along on the ice surface,
  running with the flow. They are dark and clearly distinct from the white ice. Keep them
  NARROW - a couple of stripes, not a field of debris.
- MELTWATER: intense TURQUOISE pools and one narrow meltwater channel cutting down into the
  ice. This is the only strongly coloured thing on the map and it must be unmistakably
  BLUE - much bluer than the ice around it.
- ICE WALLS at the outer rim of the picture: where the glacier ends, deep blue-green ice
  cliffs showing how thick the ice is, with dark bare rock beyond them.

THE OPEN GROUND - what the game needs:
- Between and around those features, the ice must leave WIDE, CLEAN, OPEN AREAS of plain
  snow surface - generous connected pockets, each big enough to hold several buildings, with
  nothing standing in them at all.
- Every stretch of the road must have such an open pocket beside it within a short distance.
  A stretch of road walled in by crevasses on both sides is a stretch nobody can defend.
- Inside those pockets: no seracs, no rubble, no ice blocks, no boulders, no debris. Flat
  surface texture only.

THE ROAD:
- An ancient PAVED CAUSEWAY laid across the glacier, kept swept clear - one continuous ribbon
  of DARK, NEARLY BLACK stone slabs. It must read as the darkest thing on the open ice.
- It is NOT pale, NOT grey-white, NOT snow-covered, NOT an ice track, and it never blends
  into the snow.
- It enters at the LEFT edge near the TOP, runs down and to the right across the whole map in
  a long descending line with two broad hooks in it, and ends at a small dark stone gatehouse
  low in the frame, about two thirds of the way across.
- It THREADS BETWEEN the crevasse fields - the ice dictates its route, so it bends around
  them rather than crossing them.
- Constant width for its whole length, about 5% of the image width, edge to edge. No
  widening, no plaza, no fork, no side path, no bridge, no gate across it.
- It never crosses itself, and nothing overlaps or hides any part of it.

THE FRAME:
- The top 6%, a column down the right 7% of the image to just past half its height, and the bottom-left corner (the left 14% of the bottom 8%) are covered by interface in the game. Fill those
  areas with seracs, crevasse fields, moraine or the ice walls, and put nothing there the
  player needs to see. Keep the road and the gatehouse out of all three.

LIGHT:
- Bright, flat, even winter daylight from the upper left. Lit EVENLY corner to corner: no
  cloud shadows, no dark corners, no vignette, no blue dusk, no aurora, no god rays. Err
  bright - a moody blue glacier makes every building placed on it look pasted on.
```

**Measuring it.** Both switches are needed, and the road one especially: the road detector is
"pale and not green", which a snowfield satisfies, so without `--road` the tool decides 69%
of the image is road and reports a meaningless 0% band.

```
python tools/art_match.py <board.png> --ground=232,238,247 --tol=55 --road=85,88,95 --roadtol=45
python tools/build_mask.py <board.png> --ground=232,238,247 --tol=55
```

Eyedrop both colours off the finished painting before trusting either. Reject on the **band**
figure and on the trees: one conifer anywhere means the brief was read as the meadow again.

### Attempt 2 landed. What it measured, and what it cost

`great_glacier_v1.png` is in the game as `glacier` / **Glacier Pass**. It is a different
place rather than a repaint: no trees anywhere, crevasse fields, seracs, moraine stripes,
turquoise meltwater and blue ice walls.

| | glacier v1 | **glacier v2** | winding | s | spiral |
|---|---|---|---|---|---|
| open band (want 80%) | 72% | **OK** | 62% | 74% | 78% |
| open ground | 68.6% | **48.8%** | 53.5% | 67.2% | — |
| buildable spots | 46 | **28** | 33 | 29 | 24 |
| road | 1527px | **1685px** | 3199px | 2518px | 4042px |
| towers to cover 95% | 3-4 | **4** | 5-8 | 4-5 | 6-8 |
| `--play-sim` floor died | 28 | **36** | 32 | 36 | 36 |

**v1 was the roster's generous pole and v2 is not.** The re-generation that fixed its road
(see below) also let the crevasses cut further into the ice, which took it from 46 buildable
spots to 28 and from the earliest floor-player death of the four to joint best. That was not
asked for and is worth knowing: a board's capacity is a property of the PAINTING, so any
re-generation re-rolls it and it has to be re-measured rather than assumed to carry over.

**The road was traced by tool, not by hand.** `tools/trace_ribbon.py` was written for it and
`GLACIER_PATH` is its first output; the preview put the line down the middle of the road for
its whole length on the first run, once the tracer was taught to take the largest connected
run rather than the first cell it found (dark ice walls and moraine match the road colour and
form their own islands, and seeding in one of those traced an 11px speck at the top border).

**Every colour reader needed telling what the board is made of.** This is the real lesson of
the biome work, and it cost four separate fixes:

| reader | default test | what it did on ice |
|---|---|---|
| `build_mask.py` open | `(g-b) > 35` | found no ground at all — a black mask, reported as 0% |
| `art_match.py` road | "pale and not green" | **69% of the image read as road**, so the band came out 0% |
| `water_mask.py` / water | `b > r+25` | **59% of the image read as water** — the whole map would ripple, and water is excluded from open ground |
| `art_match.py` hue | ground blue vs masonry blue | meaningless on snow; ignore it, the band and squash still hold |

All three now take `--ground`, `--road` and `--water`, and all three keep the green path
byte-identical. The failure mode they shared is worth stating on its own: **none of them
errored.** Each returned a plausible number that was wrong, which is the kind of result that
gets believed.

Measured with:

```
python tools/art_match.py <b> --ground=210,222,236 --tol=48 --road=70,72,78 --water=20,130,165
python tools/build_mask.py <b> --ground=210,222,236 --tol=48 --water=20,130,165 --watertol=95
python tools/water_mask.py <b> <b>_water.png --water=20,130,165 --watertol=50
python tools/trace_ribbon.py <b> --road=75,82,88 --tol=50 --name=GLACIER --preview=check.png
```

Note the water tolerance differs between the two uses on purpose: 95 for the build mask,
where catching a little extra blue only refuses ground, and **50** for the ripple mask, where
95 also caught the crevasse interiors and set the cracks flowing. The pools ripple; the
cracks do not.

The camera came back at 1.000 as predicted, and was not fought.

### v2: what playing it found that measuring it had not

Three faults, all in the road, none visible in any number the tools report:

1. **The road met the left edge at y=61.** The HUD covers the world's top 48px and a creep is
   drawn `radius * 2.6` tall ABOVE its feet, so a boss (radius 38 → 99px) spawned entirely
   behind the bar with only its feet showing. v2 enters at y=219. **A spawn wants y > 150.**
2. **It ended at a painted gatehouse two thirds across** instead of leaving the map, which
   reads as a door the creeps walk into. v2 runs off the frame with nothing at its end.
3. **The bottom edge, not the right one**, for the exit: when this was written the tower
   palette covered the whole right-hand strip (world x past 1296), so a right-edge road hid its
   last stretch behind the panel and a leak happened where nobody could see it. The palette is
   a top-right column now; the frame rule above says what it still hides.

All three are now constraints in the template above, and the re-generation kept the glacier
intact — same landform vocabulary, same style, still no trees.

### Boards five and six: the volcano and the desert, as landforms

The two briefs that used to sit here were three swapped blocks each, in the form the
snowfield came out of -- and the snowfield is the reason that form is gone. Identical
structure plus a new palette is a RECOLOUR, and a recolour is not a map. So both are full
briefs now, each built on the glacier v2 template that actually worked: straight-down camera,
a landform with its own vocabulary, entry a quarter of the way down the LEFT edge, exit
through the BOTTOM edge, and no gatehouse at either end.

Each is kept beside the art it is for, and that copy is the one to paste:
`assets/art/maps/ashfall_plain_v1.prompt.txt` and `assets/art/maps/salt_basin_v1.prompt.txt`.

**Each fills a pole the roster does not have.** The four shipped boards sit between 24 and 33
build spots and between 62% and 78% open band; nothing is at either extreme.

| | landform | roster pole | reject the image if |
|---|---|---|---|
| **Ashfall Plain** (`ash`) | burnt ground at the foot of an erupting volcano | pockets between the lava flows -- measure it, do not assume it | anything built appears (ruins, walls, columns); the ground is dark rather than pale ash; lava reaches below or right of the road; the volcano is a silhouette against a sky |
| **Salt Basin** (`desert`) | the floor of an evaporated salt lake, ringed by mesas | **breadth**: the open, high-capacity board -- 60+ spots, band >= 80% | the band measures under 75%; anything stands loose in the middle of the flats; it reads as dunes or a canyon |

Two things they do NOT change: the camera is asked for straight down and not fought (every
board this repo has measured comes back 1.000), and the road's entry height, bottom exit and
missing gatehouse are the three faults playing the glacier found that no tool reported.

#### Ashfall Plain -- burnt land under a volcano

**This board was first briefed as Pompeii, a Roman city buried to its rooftops, and that
brief was rejected on sight.** `assets/art/maps/roman_ash_city_v1.png` is what it produced
and it is worth keeping as the counter-example. Three things went wrong and all three were
the brief's, not the generator's:

1. **A ruined city is a set of BUILDINGS, and this map wanted a place.** The picture came
   back as identical stamped rectangles of masonry scattered over a flat pan -- archaeology,
   not terrain. Every other board in the roster is a landform (a glacier, a basin, a forest);
   a settlement is the one thing among them that reads as scenery rather than ground.
2. **"Square corners" plus "parallel legs at least 14% apart" is a recipe for a MAZE.** The
   two rules were meant to produce a street grid whose blocks a tower could cover from
   between. Together they produced evenly spaced right-angled runs with nothing to bend them
   -- a puzzle-book maze laid on ash. Neither rule survives.
3. **The volcano was forbidden, and that was wrong.** The ban came from "the camera looks
   straight down, so there is no horizon to put a cone on", which is true and irrelevant: a
   volcano seen FROM ABOVE is a crater ring with a glowing throat and radial gullies spreading
   out of a corner, and it reads instantly. What cannot be drawn is the SILHOUETTE and the
   plume, so those are what the brief forbids now.

What replaces it is wilderness: an ash plain at the foot of an erupting volcano, with the
cone in the top-left corner seen from overhead, cooled black lava lobes as the obstacles,
stands of burnt trunks, fissure fields, and molten channels running out of the crater.

**The ground stays PALE, and that is not a stylistic retreat from "burnt".** Two measurements
forbid a dark board: `art_match.py` wants open-ground luminance >= 97, below which the towers
read as stickers pasted on the board, and a near-black track on scorched dark earth is the
"grey road on grey ash" this file already warns is untraceable. So the burnt reading is
carried by what stands ON the plain -- black clinker flows, charred trunks, soot staining,
ember glow down in the crust cracks -- while the plain itself is bright ash in daylight.

**The lava has one rule, and it is geometric rather than artistic.** It must all stay above
and left of the road's entry, in the upper-left quarter and along the top edge. Molten rock
is impassable and gets no bridge, so a channel that wanders across the route makes the board
unplayable; confining it to the quarter the road is forbidden to enter (the road may never go
above its own entry height) is what makes "it never crosses the road" checkable rather than
hopeful.

```text
[Attach THREE files, in this order:
   1. C:\Users\alica\OneDrive\Belgeler\GitHub\godot-tower-defense-\godottowerdefense\assets\art\towers\_source_fire.png
      ^ buildings that will stand on this map - match their light and their painting style
   2. C:\Users\alica\OneDrive\Belgeler\GitHub\godot-tower-defense-\godottowerdefense\assets\art\towers\_source_water.png
      ^ ditto
   3. C:\Users\alica\OneDrive\Belgeler\GitHub\godot-tower-defense-\godottowerdefense\assets\art\board_source.png
      ^ an existing map in the same game - match its RENDERING STYLE and its CAMERA. Nothing else.]

Paint a game map for a 2D tower defense, seen from directly above.

Image 3 is an existing map in the same game. Match its rendering: the same painterly finish,
the same level of detail, the same bright even daylight, and THE SAME CAMERA - looked at from
straight overhead, flat, no horizon, no sky, ground filling the whole frame. Do NOT copy
anything else from it. Images 1 and 2 are buildings that will be placed on your map; match the
direction and softness of the light on their stonework.

Aspect ratio 16:9, landscape. No transparency, no border, no vignette, no text, no watermark,
no UI, no characters, no towers, no buildings.

THE PLACE - this is the whole brief, read it before anything else:

BURNT LAND AT THE FOOT OF AN ERUPTING VOLCANO, seen from straight above. This is WILDERNESS,
not a settlement. There are NO ruins, NO walls, NO columns, NO paved city, NO houses, NO
amphitheatre and NO structures of any kind anywhere in the picture. Nothing here was ever
built by anyone.

A wide plain of settled volcanic ash, scorched and dead, with a volcano at the TOP-LEFT of the
frame and its lava running out of it across the land.

THE VOLCANO - and it is seen FROM ABOVE, which is the part to get right:
- The cone fills the TOP-LEFT CORNER of the picture. Because the camera looks straight down
  you are seeing the mountain from overhead: a broad dark cone spreading out of the corner, its
  CRATER a rough ring near the top-left with a glowing ORANGE-WHITE throat inside it, and steep
  radial gullies running down its flanks like the ribs of a fan.
- Do NOT draw it as a mountain silhouette against a sky. There is NO sky, NO horizon, NO cloud
  and NO smoke plume rising into the air - none of them exist from directly above. Heat haze
  and a faint pale glow over the crater are all you get.
- Its flanks are dark, steep, rough and clearly unwalkable. They are DARKER than the ash plain
  and read instantly as "not flat ground".

WHAT THE PLAIN LOOKS LIKE:
- The main surface is settled volcanic ash over burnt earth: PALE WARM GREY, dry, dusty,
  sunlit and clearly BRIGHT. This is the ground the player builds on and most of the picture
  is made of it. It is NOT black, NOT charred dark, NOT a night scene. The land is dead, but
  it is dead in broad daylight.
- It is NOT featureless. Long soft wind drifts and faint ripples curve across it, together
  with dark SOOT STAINING, pale streaks of finer ash, and thin CRACKS in the crust with a dull
  ember glow deep inside them. All of this is painted FLAT INTO the ground: it is texture, not
  objects, and nothing in it stands up or casts a shadow.
- Lit EVENLY corner to corner. NO smoke drifting over the ground, NO ash cloud shadows, NO
  dark corners, NO vignette, NO orange rim-light washing across the field.

WHAT BREAKS THE PLAIN UP - these are the map's real features, all of them NATURAL:
- COOLED LAVA FLOWS: broad lobes and tongues of solidified black lava, their surface a jagged
  rubble of broken clinker, raised above the ash and casting real shadow along their edges.
  Several of them, spreading downhill AWAY from the volcano, some at the edges and two or three
  reaching into the middle. They are the map's main obstacle and they are unmistakably BLACK
  against the pale ash.
- BURNT FOREST: stands of dead trees, bare charred trunks with no leaves, snapped and leaning,
  their shadows lying across the ash. Groups of them at the edges and in the corners. Nothing
  green anywhere in the picture - no leaves, no grass, no moss, no new growth.
- FISSURE FIELDS: groups of long parallel splits in the ground, dark and shadowed inside, with
  a few venting pale steam. Two or three groups.
- SCATTERED VOLCANIC BOMBS: a small number of big dark boulders thrown out by the eruption,
  each with a shallow impact scar around it. Keep them OUT of the open areas described below.

THE LAVA - the map's one strongly coloured feature, and it obeys one rule:
- TWO OR THREE narrow channels of molten ORANGE lava run out of the crater: intense glowing
  orange with black crusted banks, brightest at their centres, cooling to dark as they go.
- EVERY PART OF THE LAVA STAYS IN THE UPPER-LEFT QUARTER OF THE PICTURE AND ALONG THE TOP EDGE,
  which is ABOVE AND LEFT OF THE ROAD'S ENTRY POINT. One channel may leave the frame through
  the LEFT edge high up, above the road's entry; another may run east along the TOP edge and
  leave through the right. NO lava anywhere below or right of the road. It never touches the
  road, never crosses it, never runs through the open ash beside it, and gets no bridge.
- There is NO BLUE WATER anywhere on this map.

THE OPEN GROUND - what the game needs:
- Between and around the flows, the ash must leave WIDE, CLEAN, OPEN AREAS of plain drifted
  surface - generous connected pockets, each big enough to hold several buildings, with nothing
  standing in them at all.
- Every stretch of the road must have such an open pocket beside it within a short distance. A
  stretch of road walled in by lava flows on both sides is a stretch nobody can defend.
- Inside those pockets: no boulders, no burnt trunks, no clinker, no rubble, no debris. Flat
  ash texture only. A single picturesque rock in the middle of an otherwise open pocket ruins
  that pocket.

THE ROAD:
- An old track worn across the ash down to the bare dark rock beneath it: one continuous ribbon
  of DARK, NEARLY BLACK VOLCANIC STONE, swept clear of ash by use. It must read as the darkest
  thing on the open plain.
- It is NOT pale, NOT grey-white, NOT ash-covered, NOT cracked apart, and it never blends into
  the ash. It is a natural worn track, NOT paved, NOT flagstoned, NOT a built road - no kerbs,
  no slabs, no masonry, no square corners.
- Its shape is a long, natural, WINDING route with broad organic bends: it enters at the LEFT
  edge about ONE QUARTER of the image height down, sweeps RIGHT across the upper middle of the
  plain, hooks back down and LEFT across the centre, then turns down and right and EXITS
  THROUGH THE BOTTOM EDGE at about 70% of the image width. Three broad hooks, no hairpins, no
  zigzag, no straight lines and no right angles anywhere.
- No part of the road may go above its entry height. The road is visibly CUT OFF by the bottom
  frame and continues beyond it: NO gatehouse, NO gate, NO arch, NO terminus, NO marker, NO
  structure of any kind at either end.
- It THREADS BETWEEN the cooled lava flows - the land dictates its route, so it bends around
  them rather than crossing them.
- Constant width for its whole length, about 5% of the image width, edge to edge. No widening,
  no fork, no side path, no bridge, no steps.
- It never crosses itself, and nothing overlaps or hides any part of it.

THE FRAME:
- The top 6%, a column down the right 7% of the image to just past half its height, and the bottom-left corner (the left 14% of the bottom 8%) are covered by interface in the game. Fill those
  areas with lava flows, burnt forest, fissures or the volcano's flank, and put nothing there
  the player needs to see. Keep the road out of all three.

LIGHT:
- Bright, flat, even daylight from the upper left. Lit EVENLY corner to corner: no cloud
  shadows, no dark corners, no vignette, no dusk, no god rays, no fire glow washing over the
  plain. Err bright - a dark moody wasteland makes every building placed on it look pasted on.
```

**Measuring it.** Unchanged from the city version -- the palette did not move, only what is
standing on it. Ash is a grey, so the default `(g - b) > 35` ground test finds nothing at all
and reports 0%; the road detector's "pale and not green" would call most of the plain road.
Both have to be declared:

```
python tools/art_match.py <b> --ground=150,143,135 --tol=55 --road=45,42,40 --roadtol=42
python tools/build_mask.py <b> --ground=150,143,135 --tol=55 --water=225,110,35 --watertol=80
python tools/water_mask.py <b> <b>_water.png --water=225,110,35 --watertol=55
python tools/trace_ribbon.py <b> --road=45,42,40 --tol=42 --name=ASHFALL --preview=check.png
```

Eyedrop all three colours off the finished painting first; the numbers above are estimates.
Keep the ground tolerance TIGHT: the cooled flows at (45, 40, 38) sit about 180 away and are
safely rejected, but a wide tolerance starts admitting the darker ash banked against them.
Watch the **band** figure especially on this one: black lava lobes plus burnt stands plus the
volcano's flank is a lot of refused ground, and the plain has to stay open in spite of them.

**The lava is this board's water, and that is deliberate.** `water_mask.py` and
`build_mask.py` both take a declared `--water` colour, so handing them the lava's orange does
two useful things at once: the channels stop being buildable, and `shaders/water_flow.gdshader`
displaces them, so the lava CREEPS. The shader's only colour of its own is a blue-cyan glint
at 0.018 strength on flat water, which is invisible against orange -- everything else it does
is a UV offset of the painting. The board therefore ships with no blue water and still gets
the one animated feature every other board has. Note the two tolerances differ on purpose,
the same way the glacier's do: wider for the build mask, where over-catching only refuses
ground, and tighter for the ripple mask, where over-catching sets the wrong thing moving.

**What this board's gameplay pole is, honestly: unknown until it is measured.** The depth pole
claimed for the city version was a property of the street grid -- parallel legs a tower could
cover two of -- and it died with the grid. What is left is a plain cut into wedges by flows
radiating from one corner, which is nearer the glacier's pockets than to anything else in the
roster. `--dump-board` decides, and if it lands on top of the glacier the road is the thing to
re-roll, not the biome.


#### What the volcano board's first attempt measured

`volcanic_ash_wilderness_v1.png` obeyed the brief on everything the brief had learned to ask
for: the volcano is a crater seen from overhead with radial gullies and no sky, the lava stays
above and left of the road's entry, the road is dark, organic, enters at the left a third down
and leaves through the bottom, and there is nothing built anywhere.

```
python tools/art_match.py <b> --ground=185,176,170 --tol=48 --road=55,52,50 --roadtol=38 --water=242,158,31 --watertol=70
python tools/build_mask.py <b> --ground=185,176,170 --tol=48 --water=242,158,31 --watertol=70
```

| | volcano v1 | salt basin v1 | winding | s | glacier v2 |
|---|---|---|---|---|---|
| open ground | 55.0% | 74.1% | 53.5% | 67.2% | 48.8% |
| buildable band | OK | OK | 62% | 74% | OK |
| open ground luminance | 172.2 | 199.6 | 108.5 | -- | -- |
| ground `g - b` | **6** | 35 | -- | -- | -- |
| ground squash | 1.062 | not measured | 1.000 | -- | -- |

**Two boards in a row have now come back far too bright**, 172 and 200 against a roster lit
for about 106. That is not a coincidence and it is worth stating as a rule: the briefs all
carry "err bright - a moody board makes every building look pasted on", which was written
against the winding board's 73.3, and generators oblige past the point where the instruction
stops helping. **Every new board brief should now say bright AND bounded.**

**The ash measured `g - b = 6` - dead neutral - and that is the snowfield trap wearing a
different coat.** The brief asked for PALE WARM GREY and what arrived is a neutral grey plain
with black rock on it, which is a snowfield. Nothing else separates warm volcanic dust from
cold snow at this distance: not the trees, which are burnt either way, and not the value.
Ask for red clearly above blue and check the number, because the eye forgives it in isolation
and stops forgiving it the moment the board sits next to the glacier in the map panel.

The third fault is one no verdict line reports and the histogram shows plainly: **the picture
is two values.** 43% of it sits at luminance 160-200 and 36% below 60, with almost nothing
between. That reads as graphic rather than as ground, and it is also the real source of the
"the middle looks empty" complaint - a white field with a few black blobs on it has nothing to
look at, however much is technically in the frame.

#### The volcano edit, and why it is not the desert's edit

The desert was too empty and needed things added; this board is not, and the same edit copied
across would have made it worse. What carries over is the METHOD - deepen the value, split new
material into flat versus standing, place standing things by the 20%-of-width band rule - and
what inverts is the content: warmth instead of ochre, MID-tones instead of more objects, and
clinker REMOVED from the road's shoulder rather than rock added to the far field.

```text
[Attach TWO files, in this order:
   1. C:\Users\alica\OneDrive\Belgeler\GitHub\godot-tower-defense-\godottowerdefense\assets\art\maps\volcanic_ash_wilderness_v1.png
      ^ the map to edit
   2. C:\Users\alica\OneDrive\Belgeler\GitHub\godot-tower-defense-\godottowerdefense\assets\art\towers\_source_fire.png
      ^ buildings that will stand on this map - ONLY a colour, light and value reference, never insert them]

Edit image 1, the volcanic ash game map. Image 2 is ONLY a colour, light and brightness
reference; never insert its buildings.

KEEP THE SAME MAP. Same 16:9 framing, same straight-down camera, same painterly rendering,
same even upper-left daylight. DO NOT MOVE THE ROAD: the dark track keeps its exact route,
exact width, its left entry, both of its bends and its exit through the bottom edge - preserve
every road pixel as closely as possible. Keep the volcano, its crater and every lava channel
exactly where they are. Keep the burnt tree stands and the dark masses around the outer rim.
No buildings, no ruins, no towers, no text, no characters, no vignette, nothing green.

Three changes, and nothing else.

1 THE ASH IS THE WRONG COLOUR. It is currently neutral grey and reads as SNOW.
- Give it a clear WARM cast: pale dove grey with brown-ochre and faint rust in it, the colour
  of volcanic dust, not of snow. Red clearly above blue everywhere in the open ground.
- Bring its overall brightness DOWN by about a fifth. Still daylight, still evenly lit corner
  to corner, still the bright part of the picture - just not bleached white.
- Vary it: broad soft patches of warmer and cooler ash, pale drifts against darker settled
  dust, soot staining spreading downwind of the black flows.

2 THE PICTURE IS ONLY TWO VALUES - near-white ash and near-black rock, with nothing between.
Fill that gap, and put most of the new material in the MIDDLE of the value range:
- OLDER WEATHERED LAVA: flows that erupted long ago, now dulled to MID GREY and mid brown-grey
  under a film of ash, softer-edged than the fresh black clinker. Broad and low.
- ASH RIDGES AND DRIFTS: long low banks of drifted ash with one gently shaded side, following
  the wind across the plain.
- SOOT FANS and warm grey-brown grit spreading out from the black flows.
- EMBER CRACKS: thin fissures in the crust with a dull orange glow deep inside them, small and
  scattered, nothing like the size of the lava channels.
- The near-black clinker already in the picture stays black. Do not brighten it; add the
  middle range around it.

3 THE SURFACE TEXTURE IS TOO BUSY. The heavy swirling impasto runs at the same strength across
the whole plain and will fight with the pieces the player puts on it.
- Calm it down: keep the sense of drifted, wind-worked ash, but make the swirls softer, finer
  and much more varied - strong in places, almost smooth in others. It is ground, not brushwork.

WHERE NEW THINGS MAY GO - this is a rule, not a preference. Two kinds:
- FLAT DETAIL with no height and no shadow - soot staining, grit, ember cracks, colour
  variation, fine drift patterns - may go ANYWHERE, including right up to the edge of the road.
  More of it is always better.
- ANYTHING WITH HEIGHT that casts a shadow - ash ridges, weathered flows, rock, clinker,
  burnt trunks - must stay AT LEAST 20% OF THE IMAGE WIDTH from the nearest edge of the road
  (about 334 pixels on this 1672-wide image), on both sides, for the road's whole length.
- The few small black clinker clumps currently sitting close beside the road, in the middle of
  the picture, VIOLATE that rule: remove them and restore matching flat ash where they were.
  The strip of open ash along both sides of the causeway, and the whole inside of every bend,
  must be clear of anything that stands up.

Everything else stays: the road untouched, the volcano and lava untouched, the rim untouched,
the same light, the same straight-down camera, no sky, no horizon, no smoke plume, no snow.
```


#### The volcano's edit landed, and it is the first board to hit the value target

`volcanic_ash_wilderness_v2.png`:

| | **volcano v2** | volcano v1 | salt basin v2 | winding | s | glacier v2 |
|---|---|---|---|---|---|---|
| open ground luminance | **117.3** | 172.2 | 140.1 | 108.5 | -- | -- |
| ground `g - b` | **14-23** | 6 | 60 | -- | -- | -- |
| open ground | 59.4% | 55.0% | 84.0% | 53.5% | 67.2% | 48.8% |
| buildable band | OK | OK | 99.4% | 62% | 74% | OK |
| ground squash | 1.000 | 1.062 | 0.969 | 1.000 | -- | -- |

Measured and traced with:

```
python tools/art_match.py <b> --ground=145,124,105 --tol=62 --road=45,42,40 --roadtol=36 --water=233,137,18 --watertol=70
python tools/build_mask.py <b> --ground=145,124,105 --tol=62 --water=233,137,18 --watertol=70
python tools/trace_ribbon.py <b> --road=45,42,40 --tol=36 --name=ASHFALL --preview=check.png
```

**117.3 against a target of 105 is the closest any board has come**, and it arrived two boards
after the "err bright" rule was identified as the reason they kept overshooting. Asking for a
proportional cut from a measured start ("down about a fifth") did what asking for a direction
never did. The warmth landed with it: `g - b` moved from 6 -- dead neutral, a snowfield with
black rock on it -- to 14-23, red clearly above blue, and the luminance histogram is spread
across 20-140 instead of piling up at both ends. The two-value look is gone.

**The road traced end to end on the first setting**, 44 control points, the preview line down
the middle of the track for its whole length. Two notes for whoever wires it in:

- **The tracer returned it backwards** -- spawn at the bottom edge, keep at the left -- because
  it picks its two ends by graph diameter and has no idea which way creeps walk. The brief's
  road enters LEFT and exits BOTTOM, so the array wants reversing. That is a property of the
  tool, not a fault in the painting.
- **26.6% of the board matches the road colour** at tol 36, because the rim clinker and the
  volcano's flank are the same near-black. The largest-connected-run rule picked the road
  correctly -- this is exactly the case that rule was written for -- but the margin is thinner
  than the desert's and any re-grade should re-check it.

**One thing the edit introduced that the brief forbade: the field is no longer evenly lit.**
Ash measures 158 at the top right and 92 at the lower left, a visible gradient across the
plain. It cost no ground -- the build mask covers the dark corner as one connected region, so
the "a shadow across the meadow deletes the meadow" failure did not happen -- so it is
cosmetic rather than structural, and not worth another generation on its own. It does mean
towers in the lower left stand on ground darker than the register the roster was painted for.


#### Salt Basin -- the desert

This is the board the roster has been missing since "Long Meadow" was first written up: an
OPEN, high-capacity map, the pole all four shipped boards fail. The salt pan supplies it for
free -- a dry lake floor is empty by nature, where a meadow's emptiness has to be carved out
of a forest.

**The centre-void problem is the one to watch.** "Nothing stands in the open" plus "aim for
most of the picture open" is what made both first-attempt boards measure well and look
unfinished. The fix is not fewer open areas: `build_mask` refuses things by colour and by how
much of an 8px block matches the ground, so pattern painted FLAT at a near value stays
buildable. Salt-crust polygon cracking, old shoreline rings, braided channel scars and wind
ripples are all free, and the brief asks for all four.

```text
[Attach THREE files, in this order:
   1. C:\Users\alica\OneDrive\Belgeler\GitHub\godot-tower-defense-\godottowerdefense\assets\art\towers\_source_fire.png
      ^ buildings that will stand on this map - match their light and their painting style
   2. C:\Users\alica\OneDrive\Belgeler\GitHub\godot-tower-defense-\godottowerdefense\assets\art\towers\_source_water.png
      ^ ditto
   3. C:\Users\alica\OneDrive\Belgeler\GitHub\godot-tower-defense-\godottowerdefense\assets\art\board_source.png
      ^ an existing map in the same game - match its RENDERING STYLE and its CAMERA. Nothing else.]

Paint a game map for a 2D tower defense, seen from directly above.

Image 3 is an existing map in the same game. Match its rendering: the same painterly finish,
the same level of detail, the same bright even daylight, and THE SAME CAMERA - looked at from
straight overhead, flat, no horizon, no sky, ground filling the whole frame. Do NOT copy
anything else from it. Images 1 and 2 are buildings that will be placed on your map; match the
direction and softness of the light on their stonework.

Aspect ratio 16:9, landscape. No transparency, no border, no vignette, no text, no watermark,
no UI, no characters, no towers, no buildings.

THE PLACE - this is the whole brief, read it before anything else:

A DRIED-OUT SALT LAKE BASIN in the desert, seen from straight above. Not a dune sea. Not a
canyon. The flat white-gold floor of a lake that evaporated: a huge open pan of cracked salt
crust and firm sand, filling the frame from edge to edge, with red rock walls only at the very
rim of the picture.

THIS MAP IS DEFINED BY HOW EMPTY IT IS. It is the widest, most open map in the game and that
is the entire point of it. Aim for at least three quarters of the picture to be flat, clean,
buildable ground with nothing standing in it.

NOTHING IS GREEN except the few palms at the oasis. No grass, no meadow, no scrub, no bushes,
no cactus anywhere else.

WHAT THE GROUND LOOKS LIKE:
- The main surface is the dry lake floor: WARM GOLDEN TAN sand and pale bone-white salt crust,
  sunlit, firm and flat. This is the ground the player builds on and most of the picture is
  made of it. Bright and open - err light.
- It is NOT featureless. The salt crust is broken into a huge network of shallow POLYGON CRACKS
  like dried mud; pale mineral rings mark old shorelines; faint braided scars show where water
  once ran; gentle wind ripples cross the sand. All of this is painted FLAT INTO the ground: it
  is texture, not objects, and nothing in it stands up or casts a shadow.
- Lit EVENLY corner to corner. NO long shadows from the rim reaching into the basin, NO dark
  corners, NO vignette, NO heat haze, NO blowing dust over the ground.
- Nothing lies loose on the flats: no boulders, no scattered stones, no scrub, no bones, no
  dead wood, no dunes tall enough to cast their own shadow.

WHAT BREAKS THE FLATS UP - and there is deliberately LITTLE of it:
- CANYON WALLS AND MESAS: red-brown cliff walls and flat-topped mesas, clearly DARKER and
  REDDER than the pale floor. They mass at the OUTER RIM of the picture and ring the basin.
- YARDANGS: a few wind-carved rock fins standing out of the flats, sharp-edged and aligned the
  same way, like the wind carved them. Two or three small groups only, and none of them in the
  middle of the map.
- SALT PANS: two or three broad patches where the crust is blinding white and rougher, raised
  into low ridges. They are TEXTURE, drawn flat - the player can still build on them.
- Keep the middle of the basin clear. If you are tempted to add one picturesque rock in the
  centre of an open pan, do not: a single object ruins that whole pocket.

THE OASIS - the map's water:
- One clearly BLUE spring pool with a small stand of date palms, at an EDGE of the picture,
  away from the road. Deep turquoise-blue, the only strongly coloured thing on the map, and
  unmistakably BLUER than everything else - the game finds water by its blue and animates it.
- It must not touch the road, must not cross it, and gets no bridge or ford. Do not scatter
  extra pools or wet patches through the basin.

THE OPEN GROUND - what the game needs:
- The flats on BOTH SIDES of the road, for its entire length, are completely EMPTY for a wide
  band - at least 15% of the image width beyond each kerb. The whole inside of every bend is
  open too, all the way across.
- Beyond that band the basin keeps opening into more flat pan. More open ground anywhere is
  always better than less.

THE ROAD:
- An old caravan causeway: one continuous ribbon of COOL GREY-BLUE FLAGSTONE, the colour of wet
  slate, laid across the pale floor. It must read clearly COOLER and DARKER than the warm sand
  around it, and clearly greyer and less red than the canyon rock at the rim. It is NOT
  sand-coloured, NOT a dirt track, NOT buried, NOT sunk into the ground.
- Three or four LONG, LAZY curves - wide sweeping bends, generously far apart from one another,
  like a country lane. NOT a spiral, NOT switchbacks, NOT hairpins, NOT a zigzag, and it never
  doubles back to run close alongside itself.
- It enters at the LEFT edge about ONE QUARTER of the image height down, with broad open flats
  above it. No part of the road may go above that entry. It crosses the whole basin down and to
  the right, and EXITS THROUGH THE BOTTOM EDGE at about 70% of the image width. The road is
  visibly CUT OFF by the bottom frame and continues beyond it: NO gatehouse, NO gate, NO arch,
  NO waystation, NO terminus, NO structure of any kind at either end.
- Constant width for its whole length, about 5% of the image width, edge to edge. No widening,
  no plaza, no crossroads, no fork, no side path, no bridge, no gate across it.
- It never crosses itself, and nothing overlaps or hides any part of it.

THE FRAME:
- The top 6%, a column down the right 7% of the image to just past half its height, and the bottom-left corner (the left 14% of the bottom 8%) are covered by interface in the game. Fill those
  areas with canyon walls, mesas or yardangs, and put nothing there the player needs to see.
  Keep the road and the oasis out of all three.

LIGHT:
- Bright, flat, even desert daylight from the upper left. Lit EVENLY corner to corner: no cloud
  shadows, no dark corners, no vignette, no sunset, no god rays. Err bright - a moody amber
  desert makes every building placed on it look pasted on.
```

**Measuring it.** Sand was believed to be the one biome needing no `--ground`, on the
estimate that sunlit sand (215, 188, 140) measures `g - b = 48` and passes the default test by
accident. **The board that arrived disproved it** -- see the measurements below, where a
bleached pan lands exactly on the threshold and the undeclared reading is noise. Declare the
ground, and the road too: pale flats are "pale and not green" the same way snow is.

```
python tools/art_match.py <b> --road=110,118,128 --roadtol=45 --water=30,120,160
python tools/build_mask.py <b>
python tools/water_mask.py <b> <b>_water.png --water=30,120,160 --watertol=55
python tools/trace_ribbon.py <b> --road=110,118,128 --tol=45 --name=DESERT --preview=check.png
```

**The road's colour is a deviation from the earlier sketch, and it is about the tracer.** That
sketch asked for "pale cool grey flagstone", which is a real desert road and nearly
untraceable: pale grey on pale gold is a few units of separation, and `trace_ribbon.py` marches
the largest connected run of a declared colour. The brief asks for wet-slate grey-blue instead
-- still cool, still stone, but a clear step DARKER than the floor. It stays far from the
canyon rock too (about 100 away, safe at tol 45), so the tracer cannot wander off into the rim.


#### What the salt basin's first attempt measured

`salt_lake_basin_v1.png` came back with the road right -- left entry a quarter down, three
organic bends, bottom exit at 70%, no gatehouse -- and the open pan is genuinely the roster's
most generous ground:

| | salt basin v1 | winding | s | glacier v2 |
|---|---|---|---|---|
| open ground | **74.1%** | 53.5% | 67.2% | 48.8% |
| buildable band | OK | 62% | 74% | OK |
| open ground luminance | **199.6** | 108.5 | -- | -- |

Two findings, and neither is the one the eye reports first (which was "it looks empty").

**1. `art_match.py`'s value verdict is a FLOOR, and this board sails over the ceiling nobody
wrote.** Open ground measures 199.6 against a roster whose tower masonry runs 49.9 to 124.6
and against every other board's ~106. The check passes because it only ever asked "is the
board bright enough that the towers do not look pasted on"; the winding board's 73.3 is what
it was written against. At 199.6 the failure is the mirror image -- a bleached pan with dark
towers standing on it -- and the tool reports OK. **Read the number, not the verdict.**

**2. The doc's own "desert needs no `--ground`" exception was wrong, and wrong in the way
these mistakes always are: it returned a plausible number.** That line came from an ESTIMATE
of sunlit sand at (215, 188, 140), `g - b = 48`, comfortably over `build_mask.py`'s threshold
of 35. The painting that arrived is bleached: its sand measures (235, 208, 173), `g - b = 35`,
sitting exactly ON the threshold, with **42% of the whole image inside the 30-39 bucket**. So
the default test flips a coin per pixel across the entire basin. Undeclared, the band read
"65% -- TOO CLOSED"; declared, the same painting reads OK and 74.1% open. Measure this board
as:

```
python tools/art_match.py <b> --ground=233,208,175 --tol=62 --road=135,135,135 --roadtol=40 --water=30,142,157
python tools/build_mask.py <b> --ground=233,208,175 --tol=62 --water=30,142,157 --watertol=90
```

The road came back pale grey cobble at about (135, 135, 135) rather than the wet-slate
grey-blue the brief asked for -- traceable, since it is the only cool thing in a warm
picture, but only just. Re-eyedrop it on any re-generation.

#### The edit that fixes both, and the rule it turns on

Emptiness and brightness have one fix between them, because half of "it looks empty" is that
nothing in the picture has a different VALUE from anything else. The edit deepens the sand
while leaving the salt crust pale, and adds features -- but the features split into two kinds
whose difference is the whole of the placement rule:

- **Flat detail is free and unlimited.** `build_mask.py` refuses by colour and by how much of
  an 8px block matches the ground, so polygon cracking, channel scars, shoreline rings, gravel
  fans and ripples painted FLAT at a near value stay buildable. They may go right up to the
  kerb.
- **Anything with height costs build spots exactly where the game measures them.** The band
  `art_match.py` reports is 70-300 world px from the road, which on a 1672px painting is a
  strip about 20% of the image width on each side. So standing rocks are welcome anywhere
  BEYOND that strip and forbidden inside it -- which is also the honest version of the
  original brief's "keep the middle clear", stated as a distance instead of a wish.

```text
[Attach TWO files, in this order:
   1. C:\Users\alica\OneDrive\Belgeler\GitHub\godot-tower-defense-\godottowerdefense\assets\art\maps\salt_lake_basin_v1.png
      ^ the map to edit
   2. C:\Users\alica\OneDrive\Belgeler\GitHub\godot-tower-defense-\godottowerdefense\assets\art\towers\_source_fire.png
      ^ buildings that will stand on this map - ONLY a light and value reference, never insert them]

Edit image 1, the desert salt-basin game map. Image 2 is ONLY a lighting and brightness
reference; never insert its buildings.

KEEP THE SAME MAP. Same 16:9 framing, same straight-down camera, same painterly rendering,
same bright even daylight from the upper left. Above all, DO NOT MOVE THE ROAD: the grey
cobbled causeway keeps its exact route, its exact width, its left entry, all three of its
bends and its exit through the bottom edge. Keep the oasis pool and its palms exactly where
they are. Keep the red-brown rock walls around the rim. No buildings, no ruins, no towers, no
text, no characters, no vignette.

Two things to change, and nothing else.

CHANGE 1 - THE GROUND IS TOO BRIGHT AND TOO UNIFORM. Deepen and enrich it:
- The sand is currently bleached almost to white paper. Bring it down to a DEEPER, WARMER
  GOLDEN OCHRE - honey and amber rather than bone. Roughly a third less bright overall, still
  clearly sunlit, still evenly lit corner to corner, but with real colour in it.
- Keep the SALT CRUST pale, near-white and cool. Deepening the sand while the salt stays pale
  is the point: the contrast between the two is what the picture is missing.
- Vary the ground's tone across the basin: broad soft patches of paler and deeper sand, rust
  and pale mineral staining, faint bands of coarser darker grit. Nothing uniform.

CHANGE 2 - ADD NATURAL FEATURES SO THE BASIN IS NOT EMPTY. There are two kinds and the
difference between them decides where each may go.

FLAT DETAIL - things painted INTO the ground with no height and no shadow. These may go
ANYWHERE, including right up to the edge of the road, and the more of them the better:
- Much stronger salt-crust POLYGON CRACKING - a big network of shallow plates across the pan.
- Braided DRY CHANNEL SCARS where water once ran into the basin, wandering across the flats.
- Old SHORELINE RINGS - concentric pale mineral bands marking where the lake shrank.
- Fans of darker GRAVEL and coarse grit spreading out from the rim.
- Wind ripples in the loose sand, and faint drifts against nothing.

STANDING FEATURES - things with height that cast a real shadow. These are what the map has
too few of, and they must obey ONE placement rule:
- ROCK CLUSTERS: groups of weathered red-brown boulders, three to eight stones together, the
  same rock as the rim. Six or seven such clusters across the basin.
- LOW SHELVES of bedrock breaking through the pan, with a shadowed edge on one side.
- A few small wind-carved rock fins, sharp-edged and all leaning the same way.
- THE RULE: no standing feature may come within 20% OF THE IMAGE WIDTH of the road, on either
  side. The strip of open flat ground running along both sides of the causeway for its whole
  length must stay completely clear - not one boulder, not one shelf, not one fin in it. That
  strip is where the game lets the player build, and a single rock in it deletes a whole
  pocket. Put the clusters in the wide far field beyond it, in the corners, and up against
  the rim.
- Group them. Six clusters of five stones reads as a landscape; thirty single stones spread
  evenly reads as scatter.

Everything else stays: the road untouched, the oasis untouched, the rim untouched, the same
light, the same camera, the same style, no sky, no horizon, no dunes.
```

Re-measure after the edit with the commands above, and expect the ground reference colour to
have moved -- eyedrop it again rather than reusing (233, 208, 175). What must NOT move is the
road: it is the thing `trace_ribbon.py` will read, and an edit that nudges it invalidates a
trace that has already been checked.


#### The salt basin's edit landed, and it is the best-measuring board in the repo

`salt_lake_basin_v2.png`, measured against every board that ships:

| | **salt basin v2** | salt basin v1 | winding | s | glacier v2 | spiral |
|---|---|---|---|---|---|---|
| open ground | **84.0%** | 74.1% | 53.5% | 67.2% | 48.8% | -- |
| buildable band (want 80%) | **99.4%** | OK | 62% | 74% | OK | 78% |
| open ground luminance | **140.1** | 199.6 | 108.5 | -- | -- | 106.4 |
| ground `g - b` | **60** | 35 | -- | -- | -- | -- |
| ground squash | 0.969 | -- | 1.000 | -- | -- | -- |

**99.4% of the band open is the first time any board has cleared that bar**, and it is what
the two-kinds rule bought: the flat detail the edit added -- polygon cracking, channel scars,
shoreline rings, gravel fans -- costs nothing, and every standing rock went into the far field
where the band never looks. The board is emphatically the breadth pole it was briefed as.

**The threshold straddle is gone too.** Warming the sand moved `g - b` from 35 to about 60, so
the default green test and the declared-ground test now AGREE (140.1 against 142.2) where on
v1 they disagreed by a whole verdict. A board measuring the same two ways is a board whose
numbers can be trusted; this one no longer needs `--ground` at all.

Value came down from 199.6 to 140.1 against a target of 105 and a roster whose masonry runs
50-125. That is no longer the mirror-image failure it was, but it is still the brightest board
in the game, and whether it needs a last nudge is a question for a screenshot with towers
standing on it rather than for another measurement. `grade_board.py` is the lever if it does.

**`--against` reported ROAD MOVED, and it was a false alarm worth recording.** The check ran
with the DEFAULT road detector -- "pale and not green" -- which matched 21429 blocks on the
bleached v1 (most of the pan, not the road) against 1844 on the warm v2. It compared two
garbage masks and produced a confident verdict from them: "median 44px, 46.8% within
ROAD_HALF, re-trace the path". The road had not moved at all. **Pass `--road` to `--against`
on any board whose ground colour changed between the two images**, or the comparison measures
the detector rather than the edit.

The trace confirms it, and the road came out on the first good setting -- left edge to bottom
edge, 38 control points, the preview line down the middle of the causeway for its whole
length:

```
python tools/trace_ribbon.py <b> --road=120,118,112 --tol=75 --name=DESERT --preview=check.png
python tools/build_mask.py <b> --ground=195,133,72 --tol=55 --water=29,129,145 --watertol=90
```

Note the trace needed tol **75** and the matching set is 11.4% of the board: the edit warmed
the ROAD along with the ground, from the briefed wet-slate grey-blue to (142, 137, 125). It
still traces cleanly because it is the only cool-neutral thing in a warm picture, but the
margin is thinner than the glacier's and any further re-grade should re-check it.

**What is left to find out is whether it is too EASY.** 84% open ground and a road that traces
to roughly 1390 world px -- shorter than the glacier's 1681, the shortest in the roster -- is a
lot of ground watching a little road. `--dump-board` and `--play-sim` decide that, and the
lever if it is too generous is the ROAD (longer, or further from the rim), not the openness,
which is the whole point of this board.


### What still assumes green, and does not matter much

`art_match.py`'s **hue** verdict compares the open ground's blue channel against the tower
masonry's. On snow that comparison is meaningless (snow's blue is ~245 against masonry's 46)
and it will report a failure that means nothing. Its **squash**, **value** and **band**
numbers stay valid on any biome, and those are the three worth rejecting a board on.
