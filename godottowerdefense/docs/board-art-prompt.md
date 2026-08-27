# Generating a board painting

The board is the one asset every other asset was generated against: the six tower sets and
all eleven creep cycles were painted by attaching a board and asking the generator to match
its camera, light and palette. So a new board is not just a picture — it is the reference
the rest of the art already committed to. **Attach the board being replaced**, and change
the road and the ground, not the world.

This file is the prompt and the checklist around it. The pipeline it feeds is in
[CLAUDE.md](../../CLAUDE.md) ("The board is measured, not eyeballed").

## Why this board is being generated

The winding board (`assets/art/maps/winding_forest_close_v1.png`) is a dense forest with
meadow only in the interiors of its loops. Measured 2026-08-25: of the band 70-300px from
the road — the only band a tower's range can reach — **17% is open ground**, and only 27% of
it is unambiguous meadow. That is 51 buildable spots on the whole map, and no code change
fixes it, because the rule is read off the painting.

**So the single thing a replacement must do is give the road continuous grass shoulders.**
Not "fewer trees" — shoulders: an unbroken ribbon of open meadow following the road down
both sides, all the way from the entry to the exit.

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

## The road has to be authored by hand

`tools/trace_road.py` only works on the **spiral** board: it casts rays from the keep at the
centre and follows the cobble band inward. It cannot follow an S. `Game.WINDING_PATH`'s 36
control points were read off the painting by hand and smoothed to 141 waypoints, and a new
winding board is the same job.

That is why the prompt below asks for a road that is trivially followable: one continuous
ribbon, constant width, never forking, never crossing itself, never disappearing under a
crown or a bridge. Every one of those costs an hour of hand-tracing.

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
- **Grass shoulders at least 10% of the image width beyond each kerb** — 150px on a 1536
  world. A tower stands 55px clear of the road centre-line and towers sit 68px apart, so
  110px of shoulder is one row of towers and 150px is two.
- **The rightmost 16% and the top 6% are covered by UI.** The tower palette hides 240px of
  world down the right edge and eats clicks there; the HUD bar covers the top 48px. Keep the
  road, and anything the player must see, out of both strips. Fill them with scenery.
- **Broad curves, not switchbacks.** Folding the path tighter was measured on the ported
  spiral and it makes coverage *worse*: the legs end up close enough that one tower circle
  catches several of them, and the tight folds leave no buildable ground between.

## The template

```text
[Attach the board being replaced — assets/art/maps/winding_forest_close_v1.png.]

The attached image is the current game board for a 2D tower defense seen from slightly
above. Study it first: its camera height, its light direction and softness, how saturated
its colours are, how soft its edges are, and how much detail it carries per square inch.
Paint a REPLACEMENT board that looks as if the SAME ARTIST painted it in the SAME pass —
same world, same forest, same hour of the day. Only the layout of the ground changes.

Aspect ratio 16:9, landscape, no transparency, no border, no frame, no vignette, no text,
no watermark, no UI, no characters, no towers, no buildings.

WHAT IS WRONG WITH THE REFERENCE, AND WHAT TO CHANGE:
The reference is a dense forest with the road cut through it, so there is almost nowhere
flat to stand. The replacement must be an OPEN SUNLIT MEADOW VALLEY with a forest around
its edges. The trees belong at the rim of the picture, not against the road.

THE ROAD:
- One continuous pale cobblestone road winding across the meadow in broad, sweeping
  S-curves — four or five long bends, generous and open, never a tight hairpin or a
  switchback, never doubling back close beside itself.
- It enters the picture at the LEFT edge, about a third of the way down, and leaves at the
  BOTTOM edge, left of centre. Both ends run OFF the canvas rather than stopping in it.
- Constant width for its whole length: about 5% of the image width, edge to edge. No
  widening, no plaza, no square, no crossroads, no fork, no side path.
- It never crosses itself, never passes under a bridge, an arch, or a tree crown, and is
  never hidden by anything. Every inch of it is visible from directly above.
- Total length roughly two image widths of travel.
- The cobble is a pale grey-tan stone — light, slightly cool, clearly greyer than the
  grass. NOT mossy, NOT earth-brown, NOT overgrown.

THE GROUND BESIDE THE ROAD — the most important requirement:
- An unbroken ribbon of open grass follows the road down BOTH sides for its entire length,
  at least 10% of the image width wide on each side beyond the road's edge. It never
  pinches shut, is never interrupted by a tree, a rock, a hedge, a fence or a stream.
- That grass is WARM YELLOW-GREEN, sunlit, and evenly lit corner to corner. It carries
  almost no blue. Flat, open lawn — mowed meadow, not tall grass, not scrub.
- Do NOT cast large shadows across the open grass. No cloud shadows, no long tree shadows
  reaching into the meadow, no dark corners, no darkened edges, no god rays over the
  ground. Contact shadows directly under an object are fine and should stay small.
- Keep the meadow's texture calm: a scattering of small flowers and a few faint mown bands
  are welcome, but no dense twigs, scrub, bracken or leaf litter breaking it into speckle.
- Beyond the shoulders the meadow may open into wider lawns and gentle rises. More open
  ground anywhere is always better than less.

THE FOREST AND THE SCENERY:
- Dark, blue-green conifers, massed at the outer edges of the picture and clearly SEPARATE
  from the road — a rim, a treeline on the far side of the valley, groves in the corners.
  They must read as much darker and cooler than the grass.
- The right 16% of the image and the top 6% are covered by interface in the game: fill
  those strips with dense forest, cliffs or distant hills, and put nothing there the
  player would need to see.
- A few large rocks, a fallen log or a small ruin scattered on the meadow are welcome as
  landmarks, but each must sit well clear of the road's grass shoulders.

WATER:
- At most one small feature — a pond in a corner, or a stream along the far edge. It must
  be clearly BLUE, distinctly bluer than anything else in the picture.
- Water must NEVER touch the road or the grass shoulders beside it, and must not cross the
  road. No bridges, no fords, no waterfall over the path.

MATCH THE REFERENCE ON:
- Camera. The same slightly-above three-quarter view, the same elevation. Not top-down,
  not a horizon view.
- Light. Same direction, same softness, same warm daylight.
- Palette and saturation. Muted and painterly, in the reference's register.
- Rendering. Soft painted edges, no hard black outline, the same detail density.
```

## After the image lands

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

## What the first attempt will get wrong

Recorded so the second attempt does not have to rediscover them — these are the failure
modes the constraints above are written against, and a generator drifts back to all of them
when the prompt is loosened:

- **Trees creeping back to the roadside**, because a road through a wood is the more
  beautiful picture. It is also the picture that has nowhere to build.
- **Dramatic lighting** — a shaft of light on the road, shadow everywhere else. The mask
  reads that shadow as forest and deletes the map.
- **A tight, decorative spiral or hairpin**, which looks like a game board and measures
  worse than a lazy curve.
- **A stream crossing the road**, which is the one water feature that both blocks placement
  at the crossing and needs a bridge the tracer cannot see under.
