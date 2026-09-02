# Generating the title-screen key art

The menu is `run/main_scene`, so this painting is the first thing anyone ever sees of the game.
It lands at `assets/art/menu/menu_bg.png` and is drawn by a plain `TextureRect` in
`scenes/Menu.tscn` — no shader, no camera, no `_draw()`.

## What this file is NOT

[docs/board-art-prompt.md](board-art-prompt.md) is the long one, and almost none of it applies
here. **Four tools read a board painting and turn its colours into rules** — `build_mask.py`
decides where a tower may stand from `(g - b) > 35`, `trace_road.py` finds the road by
`r > 140`, `water_mask.py` finds the water by `b > r + 25`, and `art_match.py` measures the
camera off the road's width. Every one of the board brief's colour laws exists to keep those
four working.

**Nothing reads this image.** No mask, no trace, no `art_match.py` run, no `GROUND_SQUASH`. A
shadow across the meadow costs nothing here; grey water is fine; the camera may be anything
that looks good. Do not carry the board rules over — they would only make the picture worse for
no reason. The only hard constraints are composition and legibility, and they come from the UI.

## What the UI leaves free

The design resolution is **1280x720** (`project.godot`, `window/stretch/mode="canvas_items"`,
aspect `keep`), so the picture is always shown at 16:9 and letterboxed on other windows.

The menu is a single column pinned to the LEFT, vertically centred, carrying the title, the
subtitle, the Essence/Best/stars line and six buttons, with a horizontal black gradient
(`Scrim`) behind it. Two widths matter and they are deliberately different: the button panel
stops at its own **264px** (`Center` at `offset_left = 44`, and the `Panel` takes
`size_flags_horizontal = 0` so it does not stretch), ending around **x 329** of 1280 — while the
56px title overhangs it to about **x 400**, because type can sit on sky and cliff where a panel
cannot.

So the brief below asks for the **left 35% (0-896px of 2560)** to be quiet. That is more than
the panel strictly needs, and the margin is the point: it is what absorbs a creature landing
further left than asked, which is exactly what happened (see the failures section). Treat 35%
as the request and x 329 as the hard floor.

Everything from x 1024 rightwards is free, and that is where the four avatars go.

The two overlays — How to Play and the Workshop — are centred modals with their own opaque
panels, so they do not constrain the art.

## The four avatars must be THE four avatars

The element avatars are real creatures in the game: they arrive on waves 10/20/30/40 and their
sheets are already painted (`Enemy.art_kind()` picks `boss_<element>_1..N.png`). A title screen
showing four invented elementals would be advertising a game that does not exist.

That is what the attachments are for, and the prompt says so twice, because "draw a fire
elemental" is the instruction a generator wants to follow and "redraw THIS fire elemental" is
the one it drifts away from.

## The template

```text
[Attach FIVE images, in this order:
   1. assets/art/enemies/_source_boss_fire_walk.png    - the Fire avatar
   2. assets/art/enemies/_source_boss_water_walk.png   - the Water avatar
   3. assets/art/enemies/_source_boss_nature_walk.png  - the Nature avatar
   4. assets/art/enemies/_source_boss_earth_walk.png   - the Earth avatar
   5. assets/art/maps/winding_forest_cleared_v7_graded.png - the world they live in]

Paint one wide title-screen illustration for a fantasy tower defense game.

THE FOUR CREATURES ARE GIVEN, NOT INVENTED. Images 1-4 are animation sheets of the game's four
element bosses - Fire, Water, Nature and Earth. Each sheet shows the SAME creature in several
walking poses. Your painting contains these four creatures and no others. Redraw each one
faithfully: the same silhouette, the same body plan, the same proportions, the same materials,
the same colours, the same face. Do NOT design new elementals, do NOT restyle them, do NOT swap
one for a more obvious version of its element. If a creature's sheet shows it with four limbs
and a cracked stone shell, that is what it has.

Image 5 is a map from the same game. Take the WORLD from it - a conifer forest valley with pale
grey-tan stone, warm sunlit grass and muted painterly colour - and the light: bright open
daylight from the upper left, soft-edged, no hard cast shadows. Do not copy its layout; it is
there for palette and place, not composition.

THE COMPOSITION - this is the part that has to be right:
- 16:9 landscape, 2560x1440. No transparency, no border, no frame, no vignette, no text, no
  title, no logo, no watermark, no UI, no buttons.
- The LEFT THIRD of the picture is deliberately QUIET. Dark forest, mist, a shadowed cliff
  face, distant trees - background only. Nothing important happens there, nothing needs to be
  read there, and no creature stands there. Interface will be drawn over it.
- The four creatures mass in the RIGHT TWO-THIRDS, arranged across the frame so that all four
  are FULLY VISIBLE. None of them overlaps or hides another. Each one reads clearly as its own
  silhouette from a distance.
- They are large and near the viewer - this is a hero shot of four bosses, not a landscape with
  small figures in it. Together they should fill most of the height of the right side.
- Arrange them as a line-up facing the viewer: a confrontation, not a battle in progress. No
  motion blur, no combat, no towers, no buildings, no projectiles, no human characters.

THE LOOK:
- The same painterly, matte, softly-rendered style as images 1-5. Soft painted edges, no hard
  black outline, muted saturation. Not glossy, not neon, not photoreal, not cel-shaded, not
  concept-art sketchy.
- Each creature carries a restrained glow in its own element's colour - Fire warm orange, Water
  cool blue, Nature green, Earth warm brown. Restrained: a lit core and a soft rim, not a light
  show. The picture must stay readable behind white and gold text.
- Keep the overall value MID-TO-DARK so light interface text sits on top of it, but do not
  black the picture out - the creatures themselves stay well lit and clearly visible.
- Depth: forest and cliffs behind, the ground the creatures stand on in front, a little
  atmospheric haze between them.
```

## After the image lands

1. **Check the aspect ratio first.** If it comes back 3:2 or square, crop to 16:9. Crop from the
   TOP and BOTTOM equally, never from the left — the quiet left third is the whole point.
2. Check the left third really is quiet. Lay the menu over it mentally: title at 56px, six
   buttons, all in white and gold. If a bright creature or a lit rock is sitting under that
   column, the picture fails here regardless of how good it looks on its own.
3. Save it as `assets/art/menu/menu_bg.png`.
4. Run Godot once with `--import`.
5. **Flip `mipmaps/generate` to `true` in `assets/art/menu/menu_bg.png.import` and re-import.**
   A newly added PNG arrives with it `false` (CLAUDE.md, "Known traps"), and the `TextureRect`
   is set to `TEXTURE_FILTER_LINEAR_WITH_MIPMAPS` — without the chain it samples one texel out
   of a large block and sparkles.
6. **Look at the file size.** This goes into the web export and the APK, both of which ship
   whole. The board paintings are 1672x941 lossless for reference. If 2560x1440 comes out over
   ~3 MB, downscale it to 1920x1080 — the image is only ever shown at 1280x720.
7. Point `Background.texture` in `scenes/Menu.tscn` at it (an `ext_resource`; the `Background`
   TextureRect is already `expand_mode = 1`, `stretch_mode = 6` KEEP_ASPECT_COVERED and
   `texture_filter = 3`), and if this replaces a previous version, add the old file to BOTH
   `exclude_filter` lines in `export_presets.cfg` — superseded art stays in the repo and out of
   the build, the same way the old boards do. Then photograph the result:

   ```
   Godot.exe --path <project> res://scenes/Menu.tscn --quit-after 200 -- --shot:2
   ```

   Without `--headless` — a headless run never draws, so it passes this silently.

## What the first attempt actually got wrong

Recorded from the run that produced the shipped `menu_bg.png`, which took two passes:

- **The four creatures came back at wildly different heights** — Nature towering over the rest,
  Water small — even though the sheets attached are all of comparable creatures. The second pass
  was an EDIT prompt that fixed only the sizes (`menu_bg_v1.prompt.txt` and
  `menu_bg.prompt.txt` are both kept beside the art), and the wording that worked named a
  common target and a direction per creature: "use Fire's current visible body height as the
  common target, scale Nature down about 25-30%, Water up about 20-25%". It also had to say
  "measure each from its own feet on the sloping ground to its head; do not confuse ground
  elevation with height", because the ground recedes and the generator was reading altitude as
  size. Worth folding into the first prompt next time rather than paying for a second pass.
- **The quiet left third was only half honoured.** Fire's shoulder landed at about x337 of
  1280, inside the reserved band, so the menu column would have covered half of it. That was
  absorbed in the scene rather than by regenerating — the column moved left and its `Panel`
  took `size_flags_horizontal = 0` so it stops at its own width instead of stretching to the
  56px title's — but there is only so much of that available. Budget for the left third to
  come back narrower than asked.

## What else the first attempt will get wrong

- **New elementals instead of these ones.** The single most likely failure, and the reason the
  sheets are attached and named twice. A generator has a strong prior for "fire elemental" and
  a weak one for "this particular fire elemental"; check the silhouettes against the sheets
  before looking at anything else.
- **A busy left third.** Composition wants to fill the frame, and an empty third looks like a
  mistake to anything optimising for a standalone picture. It is not a mistake here — it is
  where the menu goes.
- **Text.** Asked for a title screen, generators add a title. There is no room for one: the
  words are drawn by Godot as real Labels, so a painted "ELEMENT TD" would sit under the actual
  one.
- **Creatures overlapping into one mass.** Four large figures in two-thirds of a frame is tight,
  and the easy composition stacks them. All four must read separately.
- **Too much glow.** Four glowing creatures is four light sources, and the result is a bright
  picture that white text cannot sit on. The brief asks for restraint for a legibility reason,
  not a taste one.
- **Towers in the shot.** The tower sheets are the other half of this game's art and it is
  tempting to include them. They are not attached on purpose — adding buildings means getting
  their camera wrong, and the avatars alone carry the picture.
