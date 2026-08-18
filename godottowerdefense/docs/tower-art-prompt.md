# Generating a tower art sheet

The six element towers were painted one set at a time, each from a single generated sheet of
five tiers. This file is the recipe, kept because fifteen dual towers still draw the code
art and will need it.

The pipeline around it is in [CLAUDE.md](../../CLAUDE.md) ("Painted tower set"); this file is
only the prompt.

## Attach the board. This is the whole method.

The six sets were generated **twice**. The first pass described the style in words — a
named art direction, a list of materials, a camera angle in degrees. It produced six towers
that were internally consistent and wrong: hard black outlines, saturated bodies, facades
seen from a lower camera than the map's, sitting on a soft painted board they clearly did
not belong to. The complaint that started the second pass was "the towers look like they
are from another game", and that was exactly right.

The second pass attached `assets/art/board_source.png` to the prompt and asked the generator
to match what it could see: the map's camera height, its light direction, its saturation
ceiling, its edge softness, its detail density, and the mass of the small keep at the centre
of the spiral. Everything the first pass failed at, it fixed in one shot.

**So: attach the board image. Describe only what the image cannot show.** The generator
cannot see the game, but it can be told what the game measures — three separate defects were
fixed by writing the measurement into the prompt rather than by writing code (see below).

## The template

```text
[Attach board_source.png with this prompt.]

The attached image is the game board this asset must live on. Study it first: its camera
angle, its light direction, how saturated its colours are, how soft its outlines are, how
much detail per square inch it carries, and the small stone keep at the centre of the
spiral road. Everything below must look as if the SAME ARTIST painted it FOR THIS MAP, in
the same pass, with the same brush.

Paint a single wide game-asset sheet: FIVE upgrade tiers of one "<ELEMENT>" tower, arranged
left to right, smallest to largest, on a fully TRANSPARENT background.

MATCH THE REFERENCE ON:
- Camera. Same elevation as the keep in the reference — high enough that you look down onto
  the tops of its walls and into its basin, NOT a low front-on view of a facade.
- Light. Same direction and same softness as the map's sunlight.
- Palette. The map is muted and painterly. Keep the tower in that register.
- Rendering. Soft painted edges like the map's architecture, not a hard black cartoon
  outline. Same detail density as the keep — readable shapes, not filigree.
- Mass. A building of the same settlement as that keep, sitting IN the terrain.

The tower itself: <one paragraph. Masonry, palette, what sits in the basin at the top, the
banner sigil, the trim metal, the crystals. Name the SHAPE explicitly — see the silhouette
table below.>

<A CONTRAST OR CATEGORY NOTE, if this element has one — see "Per-element traps".>

EFFECT RESTRAINT: the <flame / water / spores / glow / floating stone> may occupy at most
the top QUARTER of the tower's height and must read as <contained in its basin>, not as a
<column / geyser / cloud / beam>. The building is the subject; the element is carried down
the rest of it by <cracks / channels / roots / gilding>.

Tier progression, growing in HEIGHT more than width, each tier the same building enlarged:
1 <a low drum, one banner, a small effect> 2 <taller, stepped base, second banner>
3 <two stages, doorway, side basins, lit window, first crystals> 4 <a fortress: crown,
chains, flanking turrets, broad stair> 5 <the grandest: larger effect, full-height detail,
a lit archway>

CRITICAL REQUIREMENTS (the reference image cannot show these — follow them exactly):
- Transparent background (alpha), no ground plane, no scenery, no backdrop, no grass under
  the towers.
- NO drop shadow and no cast shadow — the game draws its own.
- PROPORTION LIMIT: each tower's total width must be between <lo> and <hi> of its height.
- THE BASE MUST BE SYMMETRICAL. Rubble, steps and ornament at the foot must hug the tower
  evenly on both sides and must not stick out sideways below it — the game hangs the sprite
  from the middle of its lowest pixels.
- <Effects> must stay INSIDE the tower's silhouette — nothing drifting out into the
  transparent background.
- The five towers must NOT touch: at least 60 px of empty column between them.
- All five on the same horizontal baseline.
- No text, no numbers, no labels, no UI, no character.
- Canvas roughly 1774 x 887 pixels, 2:1.
```

## The three constraints that came from measurements

Each of these was a defect measured in the game, then written into the prompt, then gone.

- **Symmetric base.** `sprites.gd` `anchor()` finds where the sprite meets the ground by
  reading the middle of its bottom band. Rubble sticking out on one side moves that point:
  earth's first top tier measured 17% off its own centre and water's 8%, both because of one
  asymmetric rock apron. Naming the defect in the prompt took the whole second pass to within
  2% — most sets measure 0.
- **Effects inside the silhouette.** `cut_sprites.py` trims to the alpha bounding box and the
  game scales the result to a fixed per-tier HEIGHT. A wide halo or drifting smoke is
  measured as part of the sprite, so the height budget is spent on empty glow and the
  masonry is drawn smaller than every other element's.
- **Effect restraint (the top quarter).** The same fixed-height scaling, from the other end:
  the first darkness sheet spent nearly a third of its height on an orb and shadow, which is
  both why it read as a different game and why its building looked small. A quarter is the
  working limit; a fifth is better for elements whose effect is not their identity.

Two more that are about the board rather than the pipeline:

- **Proportion limit.** An unbounded "make it wide" draws a tower wider than `Game.TOWER_GAP`
  (68px), which buries its neighbours.
- **60px gaps.** `cut_sprites.py` splits the sheet on empty columns (`MIN_RUN`). Towers that
  touch come out as one sprite.

## Silhouette is a design channel

Sprites are scaled by **height**, so width is free to carry meaning, and the six sets use it.
Ask for the band; it is what the generator actually obeys.

| Element | Shape asked for | Why | Band asked | Drawn width |
|---|---|---|---|---|
| Light | slender spire | longest range in the game | 0.42–0.55 | 106–134px |
| Darkness | heavy obelisk | nearly as long a reach, slowest and heaviest blow | 0.45–0.55 | 144–167px |
| Nature | overgrown keep | mid range, poison | 0.55–0.70 | 147–170px |
| Water | waterworks | mid range, fastest cadence | 0.55–0.70 | 160–169px |
| Earth | quarried bastion | short range, splash, heaviest presence | 0.62–0.75 | 162–176px |
| Fire | squat forge | shortest range, fast cadence | 0.60–0.75 | 176–195px |

A tower's role should be legible before its range ring is drawn.

## Per-element traps

Each of these cost a sheet, or was caught just before it did.

- **Fire** is the element the restraint rule nearly ruined: its identity IS the flame, and a
  fifth made it unrecognisable. Give it a quarter and a *shape* instead of a budget — a fire
  contained in a basin, no taller than the basin is wide. Its stone must be **dark**, because
  orange on the map's warm green and tan has nothing to separate it.
- **Water** needs no such help: blue separates from that ground by hue alone, so its stone
  stays the keep's grey-tan.
- **Earth** must have **no gold anywhere** — the first sandy, gilded earth was mistaken for
  the Light tower at board scale, and those two must stay apart for the armour matchup to be
  readable. Grey granite, warmth only in small amber crystal.
- **Nature** risks the wrong CATEGORY, not the wrong style: the map is full of pine trees, and
  a tower crowned with a canopy reads as scenery. Ban the canopy, make the masonry the mass
  and the plants the accent, and keep the foliage several steps **darker** than the map's
  sunlit grass so the building separates by value.
- **Darkness** is the only tower darker than the ground it stands on. It needs a pale rim
  light, glowing cracks and light-toned trim, or it reads as a hole in the board.
- **Light** is made of glow and will break the muted register if allowed. Strictest version of
  every rule, plus dark accents — slate roofs, shadowed arches, deep-set windows — so a pale
  building holds its edges against the map's pale road.

## Watch list

With every tower now built from the map's grey masonry, **nature and earth are the closest
pair in the roster**. They separate by growth, banner colour and earth's battered low-slung
walls, but if two towers get confused in play it will be these.
