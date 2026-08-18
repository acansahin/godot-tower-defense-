# Generating a creep animation sheet

The nine creep archetypes are painted PNGs, and each one is an **animation cycle**:
`assets/art/enemies/<archetype>_1.png` … `_N.png`. The game reads how many frames exist off
the folder — nothing declares the number anywhere — so a creature painted with two frames and
one painted with six walk the same road, and re-animating one is a file copy.

This file is the recipe. The pipeline around it is in [CLAUDE.md](../../CLAUDE.md) ("Painted
creep"); this file is only the prompt and the traps.

**The target is six frames per archetype.** The nine are: `tutorial`, `normal`, `fast`,
`swarm`, `tank`, `air`, `immune`, `regen`, `split`.

## Attach the board, and attach the creature. This is the whole method.

Two attachments, and they do different jobs.

- `assets/art/board_source.png` — so the creature belongs to this map: its camera height, its
  light direction, its saturation ceiling, its edge softness. The tower sheets were generated
  twice because the first pass described the style in words and produced assets that were
  internally consistent and clearly from another game.
- **The archetype's existing frame** (`assets/art/enemies/<archetype>_1.png`) — so the six new
  frames are the SAME CREATURE. This is the harder half. Generating a cycle from a description
  gives six creatures that each look fine and do not match, and that reads on the board as a
  strobing flicker, not as a run.

## One sheet per creature. Six rows. One column.

Do not put several archetypes on one sheet. The tower sets could be generated five-to-a-sheet
because a tier ladder is *supposed* to change between columns; a walk cycle is the opposite —
every frame must be the same creature to the pixel, and consistency falls apart as soon as the
generator is drawing four different creatures across a wide canvas as well.

`cut_sprites.py` reads a **row per frame**:

```bash
python tools/cut_sprites.py <sheet.png> godottowerdefense/assets/art/enemies normal 220
```

A single name on a multi-row sheet is taken as a name (not as a tier prefix), so this writes
`normal_1.png` … `normal_6.png`, top row to bottom row. Add a `gap_tol` argument (the fifth,
e.g. `12`) only if the subject's silhouette reaches over the empty gap — that was needed for
the dragon's wingspan on a multi-COLUMN sheet and should not be needed here.

## The template

```text
[Attach board_source.png AND <archetype>_1.png with this prompt.]

The first attached image is the game board this creature walks on. The second is the
creature itself, already painted. Study both: the board's camera angle, light direction,
saturation and edge softness; and the creature's exact anatomy, armour, palette, weapon and
proportions.

Paint a game-asset sheet: SIX FRAMES OF A RUN CYCLE of THE CREATURE IN THE SECOND IMAGE,
stacked as six rows, one frame per row, on a fully TRANSPARENT background.

IT MUST BE THE SAME CREATURE IN ALL SIX FRAMES. Same silhouette, same armour pieces in the
same places, same colours, same weapon in the same hand, same size. Only the POSE changes.
Treat the second image as the character sheet, not as inspiration.

THE CYCLE (frames top to bottom):
1. Contact — LEFT foot striking the ground ahead, weight coming down onto it, body at its
   LOWEST.
2. Down — weight fully over the left leg, knee bent, right leg swinging through.
3. Passing — pushing off the left foot, body at its HIGHEST, right leg reaching forward.
4. Contact — the mirror of 1: RIGHT foot striking ahead, body at its lowest.
5. Down — the mirror of 2.
6. Passing — the mirror of 3.

The arms swing opposite the legs. Frames 1 and 4 are the two footfalls and must read as
impacts; 3 and 6 are the airborne part of the stride.

DRAW THE HEIGHT CHANGE. The body really is lower in frames 1 and 4 than in 3 and 6 — that
rise and fall is the bounce of the run and the game preserves it rather than flattening it.
Do not draw six poses all standing at the same height.

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
- Canvas tall and narrow — roughly 900 x 3600 pixels.
```

### The Air frame list is different

`air` is the one archetype that flies, and its cycle is a **wingbeat, not a stride**. Replace
the CYCLE block with:

```text
THE CYCLE (frames top to bottom) — ONE COMPLETE WINGBEAT, down and back up:
1. Wings at their HIGHEST, fully raised above the body, about to sweep down.
2. Wings sweeping down, roughly halfway, still above the body.
3. Wings level with the body, at full span, mid-stroke.
4. Wings at their LOWEST, fully swept down beneath the body — the power stroke.
5. Wings lifting again, roughly halfway back up.
6. Wings nearly back to the top, feathers/membrane relaxed on the recovery.

The body stays nearly still — do NOT move the creature up and down between frames; the game
does that. Only the wings travel. The head, torso and tail keep the same posture throughout.
```

Everything else in the template stands, except the "DRAW THE HEIGHT CHANGE" paragraph, which
is the exact opposite of what a flyer needs — drop it.

## Why each constraint is there

Each of these is a defect the game measured or a stage of the pipeline, not a style opinion.

- **Same creature in all six frames.** The cycle is played by swapping textures; anything that
  differs between frames and is not the pose reads as flicker. This is the single hardest
  thing to get out of a generator and the reason for one sheet per creature.
- **Facing screen-left.** `enemy.gd` mirrors the sprite through `_body.scale.x` (`_facing`)
  because the road is a spiral and a creep meets every heading on it. Art drawn facing right
  comes out backwards for half the lap.
- **Nothing below the lowest foot.** `sprites.gd` `anchor()` finds where a sprite meets the
  ground from the median of its bottom 4% of rows. A trailing cape or a dragged blade puts
  that point under the cape, and the creature walks beside the road instead of on it. The
  towers had the same defect from asymmetric rubble; naming it in the prompt fixed it.
- **Draw the height change.** `cut_sprites.py` scales every frame of one creature by that
  creature's TALLEST frame, deliberately — capping each frame to the same pixel height would
  squash the tall ones back down and cancel exactly the bounce being asked for. So a shorter
  contact pose stays shorter, and the drawn height difference survives into the game.
- **The body stays still on the Air sheet.** `enemy.gd` `_animate_flight()` already lifts the
  creature on the downstroke and drops it between beats, and breathes the ground shadow
  against that motion. Art that also rises and falls doubles it and the dragon pogos.
- **60 px empty rows.** `cut_sprites.py` splits the sheet on empty scanlines and drops bands
  under 40 px. Frames that touch come out as one sprite.
- **No shadow.** The game draws a flat ellipse for a walker and a breathing circle for a
  flyer, both keyed to its own state. A painted-in shadow rides along and reads as dirt.

## After the sheet arrives

1. Cut it: `python tools/cut_sprites.py <sheet> godottowerdefense/assets/art/enemies <name> 220`
2. Keep the sheet as `_source_<name>_run.png` beside the frames.
3. Delete the superseded frames for that archetype (a six-frame set replaces a two-frame one;
   leaving `<name>.png` behind is harmless but leaving a stale `<name>_2.png` is not).
4. Re-import:
   `"C:\Program Files\Godot\Godot.exe.exe" --headless --path godottowerdefense --import`
5. **Check the mipmaps.** A newly added PNG imports with `mipmaps/generate=false` and arrives
   looking worse than the files beside it for a reason nothing in the code shows:
   `grep mipmaps/generate assets/art/enemies/*.import` — flip the new ones to `true` and
   re-import.
6. There is no code change. `Sprites.pose_count()` counts the files and both carriers divide
   their cycle by whatever it returns.
