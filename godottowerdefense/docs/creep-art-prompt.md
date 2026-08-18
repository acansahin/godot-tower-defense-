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
