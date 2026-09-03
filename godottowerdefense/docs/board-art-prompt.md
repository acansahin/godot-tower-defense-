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
- **The rightmost 16% and the top 6% are covered by UI.** The tower palette hides 240px of
  world down the right edge and eats clicks there; the HUD bar covers the top 48px. Keep the
  road, and anything the player must see, out of both strips. Fill them with scenery.
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
- The right 16% of the image and the top 6% are covered by interface in the game: those
  strips should carry dense forest, cliffs or distant hills, and nothing the player would
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
