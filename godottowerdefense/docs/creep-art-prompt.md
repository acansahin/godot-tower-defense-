# Generating a creep animation sheet

The nine creep archetypes are painted PNGs, and each one is an **animation cycle**:
`assets/art/enemies/<archetype>_1.png` … `_N.png`. The game reads how many frames exist off
the folder — nothing declares the number anywhere — so a creature painted with two frames and
one painted with six walk the same road, and re-animating one is a file copy.

This file is the recipe. The pipeline around it is in [CLAUDE.md](../../CLAUDE.md) ("Painted
creep"); this file is only the prompt and the traps.

**The target is twelve frames per archetype.** The nine are: `tutorial`, `normal`, `fast`,
`swarm`, `tank`, `air`, `immune`, `regen`, `split`.

Twelve because the cycle is ONE STRIDE and the game plays it at the creep's own walking rate,
which is about one stride a second early in a run. Six frames is therefore **6.2 fps**, and
6 fps is slow enough that the eye counts the frames — the first six-frame goblin was rejected
on exactly that. Twelve gives 12.5 fps at wave 2 and 27 by wave 25. Past about sixteen there
is nothing left to see: the creep is drawn 62 px tall.

## Attach the board, and attach the creature. This is the whole method.

Two attachments, and they do different jobs.

- `assets/art/board_source.png` — so the creature belongs to this map: its camera height, its
  light direction, its saturation ceiling, its edge softness. The tower sheets were generated
  twice because the first pass described the style in words and produced assets that were
  internally consistent and clearly from another game.
- **The archetype's existing frame** — so the twelve new frames are the SAME CREATURE. This
  is the harder half. Generating a cycle from a description gives twelve creatures that look
  fine and do not match, and that reads on the board as a strobing flicker, not as a run.

  Which file that is depends on how far the archetype has got. `<archetype>` throughout this
  document is a key of `Game.WAVE_TYPES`, and there are nine:

  | Archetype | Attach |
  |---|---|
  | `tutorial` `normal` `fast` `swarm` `tank` | `assets/art/enemies/<archetype>_1.png` |
  | `air` `immune` `regen` `split` | `assets/art/enemies/<archetype>.png` — no `_1`, these four are single-pose |

## One sheet per creature. One column, one frame per row.

Do not put several archetypes on one sheet. The tower sets could be generated five-to-a-sheet
because a tier ladder is *supposed* to change between columns; a walk cycle is the opposite —
every frame must be the same creature to the pixel, and consistency falls apart as soon as the
generator is drawing four different creatures across a wide canvas as well.

`cut_sprites.py` reads a **row per frame**:

```bash
python tools/cut_sprites.py <sheet.png> godottowerdefense/assets/art/enemies normal 220
```

A single name on a multi-row sheet is taken as a name (not as a tier prefix), so this writes
`normal_1.png` … `normal_12.png`, top row to bottom row.

**Expect to need the fifth argument, `gap_tol`.** It is how many opaque samples a scanline
may still carry and count as background. The first six-frame goblin came out as FIVE frames
at zero tolerance: the raised axe of one frame crossed into the gap above it by a few pixels
and welded two frames into one 690px sprite. `4` fixed it. Check the tool's own line — it
prints how many rows it found — before looking at anything else:

```
python tools/cut_sprites.py <sheet.png> godottowerdefense/assets/art/enemies normal 150 4
```

The frames of a cycle are cut on ONE shared window, not trimmed individually, and they all
come out the same pixel size. That is deliberate and it is what "Why each constraint is
there" below means about the anchor.

## The template

```text
[Attach board_source.png AND the archetype's existing frame with this prompt — see the
table above for which file that is.]

The first attached image is the game board this creature walks on. The second is the
creature itself, already painted. Study both: the board's camera angle, light direction,
saturation and edge softness; and the creature's exact anatomy, armour, palette, weapon and
proportions.

Paint a game-asset sheet: TWELVE FRAMES OF A RUN CYCLE of THE CREATURE IN THE SECOND
IMAGE, stacked as twelve rows, one frame per row, on a fully TRANSPARENT background.

IT MUST BE THE SAME CREATURE IN ALL TWELVE FRAMES. Same silhouette, same armour pieces in the
same places, same colours, same weapon in the same hand, same size. Only the POSE changes.
Treat the second image as the character sheet, not as inspiration.

THE CYCLE — TWELVE frames, top to bottom, ONE COMPLETE STRIDE:
1.  Contact — LEFT foot striking the ground ahead, arms at their full opposite swing.
2.  Down — weight settling onto the left leg, knee bending, body dropping.
3.  Low — knee at its deepest bend, body at its LOWEST point of the whole cycle.
4.  Passing — left leg straightening under the body, right knee driving forward past it.
5.  Up — pushing off the left toe, body rising to its HIGHEST point.
6.  Reach — airborne, both feet off the ground, right leg extended forward to land.
7.  Contact — the mirror of 1: RIGHT foot striking ahead.
8.  Down — the mirror of 2.
9.  Low — the mirror of 3.
10. Passing — the mirror of 4.
11. Up — the mirror of 5.
12. Reach — the mirror of 6, left leg extended forward.

Frames 7-12 are the same POSES with the legs and arms swapped. They are NOT mirrored
images — the creature still faces screen-left in all twelve.

The arms swing opposite the legs throughout.

SPACE THE FRAMES EVENLY, AND CLOSE THE LOOP. Frame 12 must lead straight back into frame 1
as smoothly as 1 leads into 2 — the game plays this on repeat forever, with no pause and no
reset. Each step from one frame to the next must move the body about the SAME amount. The
last sheet failed on precisely this: measured frame to frame, the poses moved 10%, 17%, 20%,
17%, 20% of the silhouette — and then 25% from the last frame back to the first. That
oversized final step is a visible stumble once every stride, and no number of frames fixes
it.

DRAW THE HEIGHT CHANGE. The body really is lower in frames 3 and 9 than in 5 and 11 — that
rise and fall is the bounce of the run and the game preserves it rather than flattening it.
Do not draw twelve poses all standing at the same height.

CRITICAL REQUIREMENTS (the reference images cannot show these — follow them exactly):
- The creature faces SCREEN-LEFT in every frame — it moves left across the canvas.
- Transparent background (alpha). No ground plane, no scenery, no backdrop, no grass.
- NO drop shadow and no cast shadow — the game draws its own.
- NOTHING may hang below the lowest foot: no trailing cloak, no dragged weapon tip, no dust,
  no motion streaks touching the ground. The game hangs the sprite from the middle of its
  lowest pixels, so anything down there moves the creature off the road.
- At least 60 px of completely empty rows between frames, and the frames must not touch.
- Do not re-centre the frames: a pose that leans forward should sit forward on its row.
- No text, no numbers, no labels, no UI, no frame borders, no grid lines.
- ONE COLUMN: all twelve frames in a single vertical stack, not a grid.
- Canvas tall and narrow — roughly 700 x 4200 pixels.
```

### Air is a wingbeat, not a stride — use this prompt instead

`air` is the one archetype that flies, so its cycle is a **wingbeat** and its body must NOT
rise and fall (see "Why each constraint is there" below). Rather than hand-merging two blocks,
here is the whole Air prompt, ready to paste:

```text
[Attach TWO images: assets/art/board_source.png first, then
assets/art/enemies/air.png.]

The first attached image is the game board this creature flies over. The second is the
creature itself, already painted. Study both: the board's camera angle, light direction,
saturation and edge softness; and the creature's exact anatomy, wings, horns, palette and
proportions.

Paint a game-asset sheet: TWELVE FRAMES OF A WINGBEAT CYCLE of THE CREATURE IN THE SECOND
IMAGE, stacked as twelve rows, one frame per row, on a fully TRANSPARENT background.

IT MUST BE THE SAME CREATURE IN ALL TWELVE FRAMES. Same silhouette, same horns, same
markings, same colours, same size. Only the WINGS move. Treat the second image as the
character sheet, not as inspiration.

THE CYCLE — TWELVE frames, top to bottom, ONE COMPLETE WINGBEAT down and back up:
1.  Wings at their HIGHEST, fully raised above the body, about to sweep down.
2.  Wings starting down, still well above the body.
3.  Wings roughly halfway down, above the shoulders.
4.  Wings level with the body, at full span, mid-stroke.
5.  Wings below the body, driving down, membrane taut.
6.  Wings at their LOWEST, fully swept down beneath the body — the power stroke.
7.  Wings starting back up, membrane slackening.
8.  Wings roughly halfway back up, below the shoulders.
9.  Wings level with the body again, on the recovery.
10. Wings above the shoulders, folding slightly on the way up.
11. Wings nearly at the top.
12. Wings almost fully raised, one step short of frame 1 — so 12 leads straight back into 1.

THE BODY STAYS NEARLY STILL. Do NOT move the creature up and down between frames; the game
does that itself and art that also rises and falls doubles it into a pogo. The head, torso,
legs and tail keep the same posture throughout — only the wings travel.

SPACE THE FRAMES EVENLY, AND CLOSE THE LOOP. Frame 12 must lead straight back into frame 1
as smoothly as 1 leads into 2 — the game plays this on repeat forever, with no pause and no
reset. Each step from one frame to the next must move the wings about the SAME amount. A
wingbeat that hitches once a beat is as obvious as a stride that does.

CRITICAL REQUIREMENTS (the reference images cannot show these — follow them exactly):
- The creature faces SCREEN-LEFT in every frame — it moves left across the canvas.
- Transparent background (alpha). No ground plane, no scenery, no backdrop, no clouds.
- NO drop shadow and no cast shadow — the game draws its own, and breathes it against the
  beat to say how high the creature is.
- NOTHING may hang below the lowest point of the creature in any frame: no trailing tail
  tip below the feet, no dangling chain, no dust, no motion streaks. The game hangs the
  sprite from the middle of its lowest pixels, so anything down there moves it off the road.
  Note frames 5 and 6 sweep the wings BENEATH the body — the wingtips become the lowest
  pixels there, and that is fine, but nothing else may join them.
- At least 60 px of completely empty rows between frames, and the frames must not touch.
- Do not re-centre the frames: the creature keeps the same position on every row.
- No text, no numbers, no labels, no UI, no frame borders, no grid lines.
- ONE COLUMN: all twelve frames in a single vertical stack, not a grid.
- Canvas tall and narrow — roughly 700 x 4200 pixels.
```

Note there is no "DRAW THE HEIGHT CHANGE" paragraph here. That instruction is in the run-cycle
template and is the exact opposite of what a flyer needs.

## Why each constraint is there

Each of these is a defect the game measured or a stage of the pipeline, not a style opinion.

- **Same creature in all twelve frames.** The cycle is played by swapping textures; anything that
  differs between frames and is not the pose reads as flicker. This is the single hardest
  thing to get out of a generator and the reason for one sheet per creature.
- **Facing screen-left.** `enemy.gd` mirrors the sprite through `_body.scale.x` (`_facing`)
  because the road is a spiral and a creep meets every heading on it. Art drawn facing right
  comes out backwards for half the lap.
- **Nothing below the lowest foot.** `sprites.gd` `anchor()` finds where a sprite meets the
  ground from the median of its bottom 4% of rows. A trailing cape or a dragged blade puts
  that point under the cape, and the creature walks beside the road instead of on it. The
  towers had the same defect from asymmetric rubble; naming it in the prompt fixed it.
- **Draw the height change.** The frames of a cycle are cut on one shared window — as wide as
  the widest frame, as tall as the tallest, with each frame bottom-aligned inside it — so the
  files are identical in size and the game hangs the whole cycle by ONE anchor at ONE scale.
  What still differs between the files is where the creature sits inside that window, and
  that is the animation. Cutting each frame to its own bounds instead is what the first
  six-frame goblin did, and it measured an anchor 89% of the way right on the frame where the
  trailing leg reaches back against 45% on another: the creature jumps forward and swells
  once per stride. So the rise and fall you draw is preserved exactly; draw it.
- **The body stays still on the Air sheet.** `enemy.gd` `_animate_flight()` already lifts the
  creature on the downstroke and drops it between beats, and breathes the ground shadow
  against that motion. Art that also rises and falls doubles it and the dragon pogos.
- **60 px empty rows.** `cut_sprites.py` splits the sheet on empty scanlines and drops bands
  under 40 px. Frames that touch come out as one sprite.
- **No shadow.** The game draws a flat ellipse for a walker and a breathing circle for a
  flyer, both keyed to its own state. A painted-in shadow rides along and reads as dirt.

## If the generator refuses a 1:6 canvas

Twelve frames in one column is a very tall image and some generators cap the aspect ratio.
Do **not** solve it by laying the frames out in a grid — the cutter numbers a cycle by rows,
and a grid would need the two halves aligned against each other, which is exactly the
alignment the shared window exists to guarantee. Generate two sheets of six instead, attaching
the first to the request for the second and saying that these are frames 7-12 of that cycle —
then say so, because the cutter needs a small change to take one cycle from two files and put
both halves in the same window.

## After the sheet arrives

The Air cycle needed every one of steps 1-3 below, so check for them before assuming the
sheet is ready — each failure is silent, and two of them look like a good sheet in a viewer.

1. **Does it have an alpha channel?** A sheet saved without one has no empty scanlines at
   all, and the cutter returns the whole image as a single frame. Flattened white is
   indistinguishable from transparent by eye, so read the colour type — 6 is RGBA, 2 is not:
   ```bash
   python -c "import struct,sys;d=open(sys.argv[1],'rb').read();print('colortype',d[25])" <sheet>
   ```
   Re-export with transparency if you can. If you cannot: `python tools/key_white.py <in> <out>`
   lifts it off the white by flood-filling from the border and solving the one-pixel
   anti-aliased edge, which is what keeps a white rim off the silhouette.
2. **Two sheets of six?** Join them before cutting, never after — cutting each half separately
   gives each its own shared window and the creature changes size mid-cycle:
   `python tools/stitch_sheets.py <out> <frames_1_6> <frames_7_12>`
3. **Cut it, and CHECK THE ROW COUNT — it must say 12:**
   `python tools/cut_sprites.py <sheet> godottowerdefense/assets/art/enemies <name> 150 4`
   If it says 11, two frames overlap vertically. Do NOT fix that by raising `gap_tol`: the
   tolerance that separates them also shears the thin extremities off every other frame (on
   the Air sheet it cropped frame 1 from 322px to 267px, cutting the tips off the raised
   wings). Separate them by connectivity instead, then cut again with `gap_tol 0`:
   `python tools/respace_frames.py <sheet> <spaced.png> --frames 12`
4. Keep the sheet as `_source_<name>_run.png` (or `_wingbeat`) beside the frames.
5. Delete the superseded frames for that archetype — a twelve-frame set replaces a two-frame
   one, and a stale `<name>_2.png` left behind is counted as part of the new cycle.
6. Re-import:
   `"C:\Program Files\Godot\Godot.exe.exe" --headless --path godottowerdefense --import`
7. **Check the mipmaps.** A newly added PNG imports with `mipmaps/generate=false` and arrives
   looking worse than the files beside it for a reason nothing in the code shows:
   `grep mipmaps/generate assets/art/enemies/*.import` — flip the new ones to `true` and
   re-import.
8. **Look at it**, with `--air-pose` for a flyer or a timed `--shot` for a walker. The cycle
   can be geometrically perfect and still read wrong: the Air dragon came out a third smaller
   than the single pose it replaced, because a shared window sized for a full wingspan makes
   the BODY a small part of the height the game scales by. The fix was a `"radius"` entry in
   that archetype's `Game.WAVE_TYPES` row, not new art.
9. There is no other code change. `Sprites.pose_count()` counts the files and both carriers
   divide their cycle by whatever it returns.

## Element avatar bosses

The four avatar bosses (waves 10/20/30/40 of a 50-wave run, `Balance.ELEMENT_BOSS_WAVES`, one
per element in a per-run order) are painted as their OWN creatures rather than as an archetype:
`assets/art/enemies/boss_<element>_1.png` … `_12.png`, for `fire`, `water`, `nature` and `earth`.

**The lookup is wired, so this is still a file drop.** `WaveManager._spawn_boss` sets
`boss.kind` from the wave's archetype — an avatar wave pins that to `normal` — so the element is
carried by `avatar_element` alone, and `Enemy.art_kind()` prefers `boss_<avatar_element>` over
`kind` whenever that set has been painted. An element with no sheet keeps drawing the crowned
archetype exactly as before, which is what lets the four land one at a time.

Everything else — the cutter, `pose_count()`, the shared window, the anchor — is the walker
pipeline above, unchanged.

### What is different from an ordinary creep sheet

- **The element has to be IN the creature.** `_draw_sprite` deliberately does not multiply the
  archetype tint over painted art, so the blob's old "this one is the water wave" colour is
  gone. An avatar of grey stone with a blue rim is a water avatar; one painted neutral is a
  boss of no element at all.
- **Do not paint the crown or the sigil.** `_draw_crown` puts a gold crown on every boss and
  `_draw_boss_rule_icon` puts the avatar's element disc in a breathing ring 34 px above the
  head. Both are drawn in engine, over the art, every frame. A painted crown doubles; a painted
  halo fights the sigil for the same space.
- **Do not paint the ground ring either.** `_draw` lays the element ring under the feet.
- **It is drawn bigger, and that is the game's doing, not the sheet's.** `BOSS_RADIUS` 38 against
  a Normal's 24 puts an avatar at ~99 px tall on the board where a goblin is 62 — the scale comes
  from `radius * SPRITE_HEIGHT_PER_RADIUS`, so the sheet only decides the SILHOUETTE. Draw the
  bulk into the shape, not into the canvas size.
- **It walks at 0.7x** (`Balance.BOSS_SPEED_MULT`), and the cycle is played at the creep's own
  rate, so this is a heavy march rather than a run: a longer contact, a deeper settle, less air.
  Frames 6 and 12 do not have to leave the ground.
- **The roster it joins is orcs.** `normal_1.png` and `tank_1.png` are painted greenskins; an
  avatar is an elemental, so it is the one creature on the board that is deliberately NOT of
  that species. What still has to match is the render: same light from the upper left, same
  saturation ceiling, same edge softness, same painted-not-cel finish.

### The four, and the colour each must read as

The hex is `Game.ELEMENT_COLORS`, which is what the engine draws the sigil and the ground ring
in. The creature does not have to be that colour all over — it has to be unmistakably that one
of the four at a glance, at 99 px, on grass.

| Element | Sigil colour | What it is |
|---|---|---|
| `fire` | `#F2732E` | magma given a body: cracked black crust with molten seams, embers rising off the shoulders |
| `water` | `#4D99F2` | a standing wave with a shape inside it: translucent, foam at the edges, nothing dry on it |
| `nature` | `#59CC59` | grown rather than built: heartwood limbs, moss and bark plate, new growth on the back |
| `earth` | `#B88C57` | quarried: slabs of sandstone and clay, the joints packed with soil, deep and slow |

### What the first fire sheet got wrong

Every one of these was measured off the returned images, and each is now a line in the template
below. None of them is visible in a viewer — the sheet looks finished and fails downstream.

- **Four frames, not twelve — six times over.** Six separate 4-frame sheets came back. They are
  not segments of one cycle either: the first frame of each is 85-90% the same silhouette as the
  first frame of the others, so they are re-rolls of the same four poses and cannot be assembled
  into twelve.
- **No alpha channel, and a checkerboard PAINTED into the background.** All seven files are PNG
  colour type 2; one is flattened onto black. `cut_sprites.py` splits on empty scanlines, and a
  sheet with no empty scanlines is one frame. (`key_white.py` did lift the painted checker —
  80.8% of the image keyed cleanly — so a sheet in this state is recoverable, but asking for
  real transparency is one step instead of two.)
- **The poses barely travel.** Frame-to-frame silhouette overlap measured 0.92, 0.85, 0.77.
  The cycles already in the game sit at 0.59-0.88 between ADJACENT frames of twelve, and
  0.68-0.78 between frames a HALF CYCLE apart — where this sheet's half-cycle pair measured
  0.86. Played back, that is a creature shuffling in place.
- **The legs never pass each other.** This is the one that survived the rewrite, and it is
  what "it slides instead of walking" looks like as a number. Measure the width of the FEET
  (the bottom 5% of the figure) frame by frame: the shipped goblin runs 19, 24, 30, 30, 30, 32,
  36, 36, 74, 86, 98, 115 px — feet together at one end of the cycle, scissored wide at the
  other. The fire sheet runs 115, 119, 121, 124, 128, 131, 131, 132, 134, 136, 145, 148: the
  same wide stance in every frame. A creature whose legs never close never takes a step, so
  translating it along the road reads as a statue on a sled. MORE FRAMES DO NOT FIX THIS — 24
  poses of the same stance slide just as smoothly.

- **The stride was drawn half again too long.** The roster's widest step, measured against each
  creature's own height: goblin 0.77x, tank 0.78x, immune 0.78x, fast 0.82x, tutorial 0.94x,
  regen 0.61x. The fire avatar came back at **1.23x** and reads as lunging next to them. This
  one was the prompt's fault twice over — it asked for "a leg-length ahead", which on a squat
  heavy creature is enormous, and then capped the stride against the first sheet that came back
  instead of against the roster. **Say 0.8x of the creature's own height, and cap at 0.95x.**
  It costs playback too, because the cycle is paced off the stride the art was drawn with: at
  1.23x the avatar plays 6.4 fps at its first wave, at 0.8x the same 24 frames play 9.8.

- **The figure grows down the sheet.** Frame heights ran 288 → 301 → 321 → 339 px, 18% over four
  rows. The frames are cut on one shared window and hung by one anchor, so a creature that
  changes size through the cycle pulses once per stride.

### The template

```text
[Attach THREE images, in this order:
   1. assets/art/maps/winding_forest_cleared_v7_graded.png   (the board it walks on)
   2. assets/art/enemies/tank_1.png                          (the roster's render style)
   3. assets/art/towers/<element>_5.png                      (this element's own palette)]

The first attached image is the game board this creature walks on. The second is an existing
creature from the same game. The third is a building of the element this new creature embodies.
Study all three: the board's camera angle, light direction, saturation and edge softness; the
creature's painted finish, its outline weight and how its volumes are shaded; and the building's
palette and material language for this element.

Paint ONE game-asset sheet: TWELVE FRAMES OF A HEAVY WALK CYCLE of a single new creature — the
AVATAR OF <ELEMENT> — stacked as TWELVE ROWS, one frame per row, in a single vertical column,
on a genuinely TRANSPARENT background.

THE CREATURE: <the line from the table above>. It is a boss: half again the mass of the creature
in the second image, slow and deliberate, built out of the element itself rather than wearing it.
It is NOT an orc and NOT armoured in metal — the second image is there for the PAINTING STYLE
only, not for the anatomy or the species.

TWELVE. Not four, not six, not "a few key poses" — twelve rows in ONE image. Do not deliver the
cycle across several images, and do not return a shorter sheet with a note that the rest can
follow: a four-frame walk plays back as a creature shuffling on the spot, which is what the last
attempt did. If the canvas is too tall for you to render in one piece, say so instead of
silently shortening the cycle.

IT MUST BE THE SAME CREATURE IN ALL TWELVE FRAMES, AT THE SAME SIZE. Same silhouette, same
materials in the same places, same colours, same proportions, same height on every row. Measure
it: the creature in frame 12 must be the same number of pixels tall as the one in frame 1. Do
not zoom in or drift larger as the sheet goes down — the game cuts all twelve on one shared
window and hangs them from one anchor, so a creature that grows through the cycle swells and
lurches once per stride. Only the POSE changes.

THE CYCLE — TWELVE frames, top to bottom, ONE COMPLETE STRIDE of a HEAVY march:
1.  Contact — LEFT foot planting ahead, weight arriving, arms at their full opposite swing.
2.  Down — weight settling onto the left leg, knee bending, body dropping.
3.  Low — knee at its deepest bend, body at its LOWEST point of the whole cycle.
4.  Passing — left leg straightening under the body, right knee driving forward past it.
5.  Up — pushing off the left toe, body rising to its HIGHEST point.
6.  Reach — right leg extended forward to land, trailing toe still touching the ground: this
    creature is too heavy to leave it, so do NOT draw it airborne.
7.  Contact — the mirror of 1: RIGHT foot planting ahead.
8.  Down — the mirror of 2.
9.  Low — the mirror of 3.
10. Passing — the mirror of 4.
11. Up — the mirror of 5.
12. Reach — the mirror of 6, left leg extended forward.

Frames 7-12 are the same POSES with the legs and arms swapped. They are NOT mirrored images —
the creature still faces screen-left in all twelve.

THE LEGS MUST REALLY TRAVEL, AND THEY MUST PASS EACH OTHER. This is the failure of the last two
attempts. Cover the head and body of any two frames and you should still be able to tell them
apart by the legs alone. Frames 1 and 7 are the extremes — in 1 the LEFT leg is forward and the
right trails behind; in 7 it is exactly the other way round. THE STRIDE IS MODERATE, NOT A LUNGE: at its widest, the horizontal
distance between the two feet is about EIGHT TENTHS of the creature's own height, and never more
than ninety-five hundredths of it. Every other creature in this game measures 0.6-0.9 there, and
a longer step does not look grander — it reads as lunging beside them, and the game paces the
cycle off the stride it measures in the art, so it also makes the creature walk more slowly.
The arms swing opposite the legs, and they swing wide.

But the WIDE poses are only half of it. In the PASSING frames — 4 and 10 — the swinging leg
comes right past the standing one and the two feet are nearly TOGETHER, one lifted just clear of
the ground, ankles almost touching. Measured across the sheet, the horizontal distance between
the two feet must vary by at least four to one from the passing frames to the contact frames.
A cycle where the feet stay the same distance apart in every frame is not a walk: the creature
is slid along the ground in one frozen stance, and no number of frames repairs it.

SPACE THE FRAMES EVENLY, AND CLOSE THE LOOP. Frame 12 must lead straight back into frame 1 as
smoothly as 1 leads into 2 — the game plays this on repeat forever, with no pause and no reset.
Each step from one frame to the next must move the legs about the SAME amount.

DRAW THE HEIGHT CHANGE. The body really is lower in frames 3 and 9 than in 5 and 11. On a heavy
creature that rise and fall is small, but it is there — draw it, and do not draw twelve poses
all standing at the same height.

CRITICAL REQUIREMENTS (the reference images cannot show these — follow them exactly):
- TRUE TRANSPARENCY: export a PNG with a real alpha channel and nothing at all in the empty
  areas. Do NOT paint a grey-and-white checkerboard to represent transparency, and do not
  flatten the sheet onto white or onto black. The last attempt painted the checker pattern into
  the image, and the tool that cuts the frames splits on EMPTY rows — a painted background has
  none, so the whole sheet is read as a single frame.
- The creature faces SCREEN-LEFT in every frame — it moves left across the canvas.
- No ground plane, no scenery, no backdrop, no grass, no vignette.
- NO drop shadow and no cast shadow — the game draws its own.
- NO crown, no halo, no floating orb and no rune circle above the head, and no ring, glow or
  magic circle on the ground under the feet. The game draws a gold crown on the head and an
  element sigil above it, and lays the element ring under the feet, over this art.
- The element must be read from the CREATURE'S OWN BODY — its material and its colour — because
  the game applies no tint to it.
- NOTHING may hang below the lowest foot: no trailing cloak, no dragged weapon tip, no dripping
  lava, no falling embers, no dust. The game hangs the sprite from the middle of its lowest
  pixels, so anything down there moves the creature off the road.
- THE ELEMENT MUST NOT TOUCH THE GROUND. No puddle, splash, spray or wet patch under a water
  creature; no grass, roots or moss under a nature one; no rubble, dust or cracked earth under
  an earth one; no scorch mark or pooled lava under a fire one. Draw the creature and nothing
  else. What is under its feet is transparent, in every frame. This is the same rule as the one
  above and it is stated twice because it is broken differently: a puddle is not "hanging
  below", it is standing beside the feet, and it becomes the lowest pixels all the same — the
  creature then hangs from the puddle and floats over the road.
- Keep the top of the head compact — no antlers or crest spreading wide above it. The crown and
  the sigil are drawn there.
- At least 60 px of completely empty rows between frames, and the frames must not touch — no
  raised arm or trailing foot may cross into the row above or below.
- Do not re-centre the frames: a pose that leans forward should sit forward on its row.
- No text, no numbers, no labels, no UI, no frame borders, no grid lines.
- ONE COLUMN: all twelve frames in a single vertical stack, not a grid, not two columns.
- Canvas tall and narrow — roughly 700 x 4200 pixels.
```

One sheet per element, four sheets in all — the one-creature-per-sheet rule above is not relaxed
for bosses, and four elementals across one canvas is the worst case for it.

### When it comes back as two sheets of six

This is the likely outcome — twelve frames in one column is a 1:6 canvas and generators shorten
it — and the SECOND sheet is where it goes wrong. Asked for "twelve frames" twice, the fire
avatar came back as two six-frame sheets that were both the FIRST half of the stride: same leg
forward, same arm forward, frame 1 of each interchangeable. Six half-stride frames played as a
full stride is a creature hopping on one leg, so the two cannot simply be stitched.

Ask for the second half explicitly, as its own request, with the first half attached — keyed to
real transparency first (`python tools/key_white.py <sheet> <keyed.png>`), or the generator
copies the painted checkerboard back into its answer:

```text
[Attach the first sheet — frames 1-6, with real transparency.]

The attached sheet is frames 1-6 of a twelve-frame walk cycle for this creature. Paint frames
7-12: the SAME creature, the same size, the same materials and colours, in one vertical column
of six rows on a genuinely transparent background.

Frames 7-12 are frames 1-6 with THE OTHER LEG LEADING. Frame 7 is frame 1 with the legs and
arms swapped: where frame 1 has the near leg striding forward and the far leg trailing, frame 7
has the far leg forward and the near leg trailing, and the arms swap with them. Then 8 matches
2, 9 matches 3, 10 matches 4, 11 matches 5, 12 matches 6, each with the legs and arms swapped.

These are NOT mirror images. The creature still faces SCREEN-LEFT in all six, still walks to the
left, and the lighting still comes from the same side. Only which leg is in front changes.

Same height on every row, and the same height as the attached sheet — the two files are cut on
one shared window and hung from one anchor, so a size change between them lands as a lurch
halfway through the stride. At least 60 px of empty rows between frames, nothing below the
lowest foot, no shadow, no crown, no ground ring, no text.
```

Then join before cutting, never after — cutting each half separately gives each its own shared
window and the creature changes size mid-cycle:

```bash
python tools/stitch_sheets.py <out.png> <frames_1_6.png> <frames_7_12.png>
```

### Twenty-four frames

`Sprites.pose_count()` probes up to `MAX_POSES`, which is 24, so this is the ceiling the engine
reads. It buys exactly one thing — playback rate. The cycle still covers one stride at the
creep's own speed, so twice the frames is twice the frame rate: an avatar boss goes from 5.2 fps
at its first wave to 10.4, and a Tank from 5.6 to 11.2.

It buys nothing else. If the legs do not pass each other, 24 frames slide as smoothly as 12 —
see "What the first fire sheet got wrong" above. Ask for 24 only once a 12 has come back with
the feet opening and closing.

**Twenty-four in one column is a 1:12 canvas and no generator will draw it.** Ask for four
sheets of six, in order, attaching the previous sheet to each request so the creature holds. The
phases below are the whole cycle; hand over six at a time.

| Sheet | Frames | Phases |
|---|---|---|
| 1 | 1-6 | contact left, settle, down, low, rise, **passing (feet together)** |
| 2 | 7-12 | swing on, up (highest), extend, reach, drop, about to land |
| 3 | 13-18 | contact right, settle, down, low, rise, **passing (feet together)** |
| 4 | 19-24 | the mirror of sheet 2, left leg reaching |

#### Sheet 1 of 4 — frames 1-6

Attach TWO images: the creature (a keyed sheet of it, never the checkerboarded original), and a
STRIDE REFERENCE — the roster's widest step beside the one to avoid, both scaled to the same
figure height. Build that second image if it does not exist: take the widest frame of
`normal_*.png` and the widest frame of the sheet that overshot, scale both to one height, and put
them side by side.

**Show the stride, do not describe it.** Asked in words — "0.8 of its own height", "never more
than 0.95" — the generator returned 1.10x, then 1.23x, then 1.27x, three times in a row. A ratio
is not something an image model measures. The picture is.

For sheets 2-4, keep the wording and swap in that sheet's phase list from the table above; sheets
3 and 4 additionally say that the legs and arms are swapped throughout.

```text
The attached sheet shows the creature. Paint SIX frames of a walk cycle for it — frames 1-6 of a
twenty-four frame cycle — as six rows in a single vertical column on a genuinely transparent
background. Same creature, same materials, same colours, same height on every row.

The creature faces SCREEN-LEFT in all six and walks to the left.

FRAMES 1-6, one quarter of the cycle:
1. CONTACT — the LEFT foot has just landed well ahead of the body; the right leg is stretched
   far behind with its toe still on the ground. The feet are at their WIDEST apart here.
2. SETTLE — weight arriving on the left leg, knee starting to bend, body dropping slightly.
3. DOWN — the left knee bends deeper, the body drops further, the right foot lifts off behind.
4. LOW — the body is at its LOWEST point of the whole cycle, weight fully over the left foot,
   the right leg swinging forward and now only a little behind the standing leg.
5. RISE — the body starts lifting as the left leg straightens, the right knee driving forward.
6. PASSING — the right leg has swung right past the left: THE TWO FEET ARE ALMOST TOUCHING,
   ankle beside ankle, the right foot lifted just clear of the ground. This is the narrowest
   frame of the cycle.

THE SECOND ATTACHMENT IS THE STRIDE. Two figures scaled to the same height: the LEFT one steps
the way this creature must step, and the RIGHT one is the mistake — a lunge, its feet half again
too far apart. Copy the LEFT figure's spacing between the feet, relative to body height, in your
widest frame. Not wider. The creature is heavy and deliberate; heavy does not mean long-legged,
and the wide split reads as leaping, not marching.

THE FEET MUST OPEN AND CLOSE. Measured across the six rows, the horizontal distance between the
two feet must be at least FOUR TIMES larger in frame 1 than in frame 6. In frame 1 — the widest
of the whole cycle — that distance is about EIGHT TENTHS of the creature's own height, and never
more than ninety-five hundredths of it: a firm step, not a lunge or a split. Every other creature
in this game measures 0.6-0.9 there, and the game paces the walk off the stride it measures in
the art, so a longer step also makes the creature walk more slowly. A cycle where the feet
stay roughly the same distance apart in every frame is not a walk — the creature reads as a
statue being slid along the ground, and that is exactly what the last sheet did. Frame 6 with
the ankles together is the single most important frame here; do not draw it in a wide stance.

The arms swing opposite the legs: in frame 1 the RIGHT arm is forward and the left is back, and
they trade places as the legs do.

TRUE TRANSPARENCY: export a PNG with a real alpha channel and nothing at all in the empty areas.
Do NOT paint a grey-and-white checkerboard to represent transparency, and do not flatten onto
white or black.

No drop shadow, no crown, no halo, no ring or glow on the ground, no text. Nothing may hang
below the lowest foot, and NOTHING THE ELEMENT SHEDS MAY TOUCH THE GROUND — no puddle, splash,
spray, dust, rubble, roots or scorch under or beside the feet. The ground is transparent in
every frame; the game draws what the creature stands on. At least 60 px of empty rows between
frames and the frames must not touch. Do not re-centre the frames. One column of six rows,
roughly 700 x 2200 pixels.
```

#### Sheet 2 of 4 — frames 7-12

Attach SHEET 1, keyed — the creature and its size now come from there, not from any earlier
cycle.

```text
The attached sheet is frames 1-6 of a twenty-four frame walk cycle. Paint frames 7-12: the SAME
creature, the same size, the same materials and colours, as six rows in a single vertical column
on a genuinely transparent background.

The creature faces SCREEN-LEFT in all six and walks to the left. Frame 6 of the attached sheet
is the PASSING pose, with the two feet almost touching; frame 7 carries straight on from it.

FRAMES 7-12, the second quarter of the cycle:
7.  The right leg is now clearly ahead of the standing left one, still swinging forward, the
    body starting to rise onto the left toe.
8.  UP — the body is at its HIGHEST point of the whole cycle, pushing off the left toe, the
    right leg reaching further forward.
9.  The right leg extends forward, the left leg straight behind, the heel about to leave.
10. REACH — the right leg is stretched out ahead ready to land, the left toe still touching the
    ground behind. The feet are near their WIDEST here.
11. The right heel is about to strike; the body begins to drop towards it.
12. One step short of contact: the right foot is a moment from planting, the left stretched far
    behind. This frame must lead straight into a CONTACT pose on the right foot.

THE FEET OPEN AGAIN ACROSS THESE SIX, IN THIS ORDER. Frame 7 is still narrow — the feet have
only just passed each other — and they open steadily to frames 10-12, which must be at least
four times wider between the feet than the attached sheet's frame 6. Do not scatter wide and
narrow poses through the six; the order above IS the animation, and a narrow frame landing at
10 breaks the stride.

DO NOT WIDEN THE STRIDE BEYOND THE ATTACHED SHEET. At its widest — frame 1 of the attachment —
the feet are about eight tenths of the creature's own height apart, and that is the maximum here
too. Do not draw the legs in a full split. The game paces the cycle off the stride it
measures in the art, so a longer step does not look grander, it just makes the creature walk
more slowly to keep its feet on the ground.

The arms swing opposite the legs: the LEFT arm is forward through these frames, since the right
leg is.

TRUE TRANSPARENCY: export a PNG with a real alpha channel and nothing at all in the empty areas.
Do NOT paint a grey-and-white checkerboard to represent transparency, and do not flatten onto
white or black.

Same height on every row, and the same height as the attached sheet — the four sheets are cut on
one shared window and hung from one anchor, so a size change between them lands as a lurch in
the middle of the stride. No drop shadow, no crown, no halo, no ring or glow on the ground, no
text. Nothing may hang below the lowest foot. At least 60 px of empty rows between frames and the
frames must not touch. Do not re-centre the frames. One column of six rows, roughly 850 x 1850
pixels.
```

**Ask for the opening sheets ONCE and take the first three rows.** Sheets 2 and 4 — the halves
where the feet open again — came back scrambled for all three elements: the first three rows
ascend correctly and in band, and the rest is a lunge or a stray passing pose. Measured:

| element | sheet 2 rows |
|---|---|
| fire | 0.73 0.84 0.89 · 1.03 1.04 1.10 |
| water | 0.51 0.82 0.89 · 1.12 0.24 1.14 |
| nature | 0.69 0.81 0.83 · 1.12 0.37 0.19 |

Three usable rows is all the pool needs from an opening half, so re-rolling for the other three
buys nothing. Fire cost four rounds learning this.

#### Sheets 3 and 4 — frames 13-18 and 19-24

Attach the sheet being mirrored: sheet 1 for frames 13-18, sheet 2 for frames 19-24, keyed.
Substitute the frame numbers in the first line; everything else is the same request twice.

```text
The attached sheet is frames 1-6 of a twenty-four frame walk cycle. Paint frames 13-18: the SAME
creature, the same size, the same materials and colours, as six rows in a single vertical column
on a genuinely transparent background.

Frames 13-18 are the attached frames 1-6 WITH THE LEGS AND ARMS SWAPPED. Where the attachment
has the near leg striding forward and the far leg trailing, these have the far leg forward and
the near leg trailing; the arms trade places with them. The pose sequence is otherwise identical
row for row: row 1 is the widest contact, the feet close through the middle rows, and row 6 is
the passing pose with the two feet almost touching.

These are NOT mirror images. The creature still faces SCREEN-LEFT in all six, still walks to the
left, and the light still comes from the same side. Only which leg is in front changes.

Match the attachment's foot spacing row for row — the widest row about eight tenths of the
creature's height, the passing row with the ankles together — and do not draw the legs in a full
split. Same height on every row, and the same height as the attachment: the four sheets are cut
on one shared window and hung from one anchor, so a size change between them lands as a lurch
in the stride.

TRUE TRANSPARENCY: export a PNG with a real alpha channel and nothing at all in the empty areas.
Do NOT paint a grey-and-white checkerboard to represent transparency, and do not flatten onto
white or black.

No drop shadow, no crown, no halo, no ring or glow on the ground, no text. Nothing may hang
below the lowest foot. At least 60 px of empty rows between frames and the frames must not
touch. Do not re-centre the frames. One column of six rows, roughly 850 x 1850 pixels.
```

Sheets 3 and 4 are sheets 1 and 2 with the legs and arms swapped — the same instruction the
second half of a twelve-frame cycle gets, and the same trap: check that the OTHER leg occludes,
because in profile the silhouettes look alike.

Then stitch all four before cutting, never separately:

```bash
python tools/stitch_sheets.py <out.png> <s1.png> <s2.png> <s3.png> <s4.png>
python tools/cut_sprites.py <out.png> godottowerdefense/assets/art/enemies boss_fire 220 4
```

The cutter must print `24 row(s)`, and the feet measurement has to open and close about 4:1
across them exactly as it does at twelve. Four sequential requests is four chances for the
creature to drift, so compare the last sheet against the first before spending the effort:
same height, same materials, same fist and shoulder shapes.

### How the fire cycle actually got made

Eight generation rounds, and the sheet that shipped was assembled rather than generated. Expect
the same for the other three elements, and budget for it:

1. **Ask for six frames at a time, four times** (the tables above). Twelve in one column never
   arrived; six always did.
2. **Expect one lunge per sheet.** Shown a picture of the roster's stride beside its own, the
   generator still drew its CONTACT rows at 1.0-1.27x the figure height. The other rows landed
   at 0.28-0.90x, which is the band.
3. **Pool the rows that fit instead of re-rolling.** `tools/compose_cycle.py` takes
   `<sheet.png>:<row>` pairs in cycle order, aligns every frame on its BODY CENTROID — the rows
   come from separate generations that each placed the creature differently, and an un-aligned
   join reads as the creature jumping sideways once a stride — and writes one sheet for
   `cut_sprites.py`. The fire avatar's fourteen frames came out of four sheets this way:

   ```bash
   python tools/compose_cycle.py out.png s1.png:2 s1.png:3 s1.png:4 s1.png:5 s1.png:6        s2.png:1 s2.png:2 s3.png:2 s3.png:3 s3.png:4 s3.png:5 s3.png:6 s4.png:1 s4.png:2
   ```

   Order is contact -> passing for one leg, two opening frames, then the same for the other leg.
   Measured after cutting: 0.75, 0.44, 0.38, 0.33, 0.28 | 0.64, 0.89 | 0.82, 0.40, 0.40, 0.27,
   0.25 | 0.77, 0.83 — widest 0.89x, inside the roster's 0.61-0.94.
4. **Fewer frames is not automatically worse.** Playback is `frames x speed / (2 x stride)`, so
   dropping the lunges shortens the stride and speeds the cycle back up. 24 frames at 1.23x
   played 6.4 fps; 14 frames at 0.89x plays 5.2, and `Enemy.WALK_TEMPO` lifts that to 7.0.

### After the sheet arrives

Steps 1-9 of "After the sheet arrives" above apply, with three substitutions.

**Key it with `--feather` if the creature glows.** An elemental radiates, so its edge fades to
white over several pixels rather than one, and the plain matte leaves a pale rim — measured on
the fire avatar, 33% of the silhouette's edge came out pale where the hand-keyed roster measures
2%. Four passes brought it to 2.1%:

```bash
python tools/key_white.py <sheet> <keyed.png> --feather 4
```

What survives that is not background: white-HOT flame inside the creature is indistinguishable
from white background once a sheet has been flattened, and no keying can separate them (ten
passes instead of four moved it 1.3% -> 1.0%). It shows as pale wisps where the creature stands
on grass. The only clean fix is a sheet exported with real alpha.

Then cut under the boss name and at a bigger window, because a boss is drawn ~99 px tall and the
cutter targets about twice the drawn size —

```bash
python tools/cut_sprites.py <sheet> godottowerdefense/assets/art/enemies boss_fire 220 4
```

**Drop the lunge frame rather than re-rolling the sheet.** Shown the stride reference the
generator still drew its CONTACT frame as a leap — 1.15x where the roster steps 0.77x — while
the other five rows came back inside the band at 0.28-0.75x. One bad frame per sheet is not
worth another round trip: cut the sheet, measure each frame, and delete the ones over 0.95x
before renumbering. Drop them symmetrically (the same count from each half) so the loop still
closes, and remember what it buys — a shorter stride paces the cycle FASTER, so 20 frames at
0.75x play 8.8 fps where 24 frames at 1.23x played 6.4.

**An elemental paints the ground under itself, and that has to come off before the cut.** Water
drew a spray joining its feet, earth a dust smear; the sprite is hung from the middle of its
lowest pixels, so the creature ends up hanging from the puddle. `tools/strip_ground_veil.py`
peels it off a keyed sheet. Its rule is WIDTH, not connectivity, and that distinction cost a
rebuild: the first version peeled any bottom row that was one connected run, which is exactly
what a PASSING pose looks like — feet together — so it shaved the feet off those frames, left
the calves lowest, and the earth cycle then measured a 1.31x stride where the sheet had drawn
0.34x. A veil is at least 1.45x wider than the legs above it; touching feet are narrower.

**Measure the feet before believing the cycle.** Measure the CUT frames, not the sheet: the
shared window and the downscale can move the answer, and the cut files are what the game loads. The width of the bottom 5% of each cut frame,
listed in order, has to open and close — roughly 4:1 between the narrowest and the widest, like
the shipped `normal` set. Flat numbers mean a sliding statue, and that is invisible in a still.

Then look at the result with `--avatar-pose`, which walks all four avatars down an empty road
at once and prints the art set each one resolved to:

```
"C:\Program Files\Godot\Godot.exe.exe" --path godottowerdefense res://scenes/Main.tscn --quit-after 600 -- --avatar-pose --shot:3
```

A line reading `fire art=normal` means the sheet is not being picked up — wrong name, wrong
folder, or not imported — and on the board that failure looks exactly like an element nobody
has painted yet.
