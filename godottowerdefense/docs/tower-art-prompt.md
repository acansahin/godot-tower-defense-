# Generating a tower art sheet

The six element towers were painted one set at a time, each from a single generated sheet of
five tiers. This is the recipe that produced them, kept because the first set's prompt was
*not* kept and had to be reconstructed by looking at the sheet — and because fifteen dual
towers still draw the code art.

The pipeline around it is in [CLAUDE.md](../../CLAUDE.md) ("Painted tower set"); this file is
only the prompt.

## The template

Fill in the bracketed parts. Everything under CRITICAL REQUIREMENTS is load-bearing — each
line is there because leaving it out broke something real, noted below.

```text
A single wide game-asset sheet showing FIVE upgrade tiers of one "<ELEMENT>" tower for a
fantasy tower-defense game, arranged left to right, smallest to largest, on a fully
TRANSPARENT background.

Style: stylized hand-painted 2D game art, Kingdom Rush / Clash of Clans flavour — clean
readable silhouettes, crisp painted shading, saturated colours, subtle dark outline. Seen
from a 3/4 top-down isometric angle, camera about 45 degrees above, all five towers at the
EXACT SAME viewing angle and the same light direction (key light from the upper left).

The tower: <one paragraph. The masonry, the palette, what sits in the basin at the top,
the banner sigil, the trim metal, the crystals. Name the SHAPE explicitly — slim spire,
broad bastion, heavy obelisk — see "Silhouette" below.>

Tier progression, growing clearly in HEIGHT more than width:
1 - <squat, one basin, small effect, one banner>
2 - <taller, stepped base, crenellations, bigger effect, second banner>
3 - <two-stage, doorway, side basins, lit window, crystals appearing>
4 - <fortress: crown, chains, flanking turrets, broad stair, large crystals>
5 - <grandest: huge crowning effect, cascades down the walls, spires, lit archway>

CRITICAL REQUIREMENTS:
- Transparent background (alpha), no ground plane, no scenery, no backdrop.
- NO drop shadow and no cast shadow on the ground — the game draws its own.
- PROPORTION LIMIT: each tower's total width must stay between <lo> and <hi> of its total
  height.
- Any rocks, steps, grass or ornament at the foot must hug the tower's own base
  SYMMETRICALLY and must not stick out sideways below it — the game hangs the sprite from
  the bottom of its own pixels, so a stray rock off to one side tilts the tower off its
  spot.
- <Effects: glow, smoke, floating debris> must stay close to the tower and INSIDE its
  silhouette — no haze drifting far out into the transparent background, or the sprite's
  bounding box balloons and the tower is drawn smaller than every other element.
- The five towers must NOT touch or overlap: leave a clear empty vertical gap of at least
  60 px between them, and margins at the edges.
- All five standing on the same horizontal baseline.
- No text, no numbers, no labels, no frames, no UI, no character.
- Wide canvas, roughly 1774 x 887 pixels or larger at the same 2:1 aspect ratio.
```

## Why each requirement is there

- **Transparent, no shadow.** `tower.gd` `_draw_sprite()` paints its own contact shadow, so
  the sprite can be lit by whatever board it lands on. A painted shadow doubles it.
- **Symmetric base.** `sprites.gd` `anchor()` reads the bottom band of the sprite to find
  where it meets the ground. Rubble sticking out on one side moves that point: earth's top
  tier landed 17% off its own centre before the anchor rule was made robust, and water's is
  still 8% off because its right-hand waterfall apron is genuinely asymmetric. The rule now
  survives a bad sheet, but a symmetric one still measures better.
- **Effects inside the silhouette.** `cut_sprites.py` trims to the alpha bounding box and
  the game scales the result to a fixed per-tier HEIGHT. A wide halo or drifting smoke is
  measured as part of the sprite, so the height budget gets spent on empty glow and the
  masonry is drawn smaller than every other element's.
- **Proportion limit.** Same fixed-height scaling: an unbounded "make it wide" draws a tower
  wider than `Game.TOWER_GAP` (68px), which buries its neighbours. Measured tops of the
  ladder: light 0.44, darkness 0.47, nature 0.50, water 0.56, fire 0.60, earth 0.51.
- **60px gaps.** `cut_sprites.py` splits the sheet on empty columns (`MIN_RUN`). Towers that
  touch come out as one sprite.
- **1774 x 887.** What every accepted sheet has been. The tool downscales anyway, so bigger
  is fine; the 2:1 shape is what fits five tiers in a row.

## Silhouette is a design channel

Sprites are scaled by **height**, so width is free to carry meaning, and the six sets use it:

| Element | Shape asked for | Why | Widest tier |
|---|---|---|---|
| Light | slim spire | longest range in the game | 126px |
| Darkness | heavy obelisk | nearly as long a reach, slowest and heaviest blow | 136px |
| Nature | vine-covered keep | mid | 144px |
| Earth | broad bastion | short range, splash, heaviest ground presence | 150px |
| Water | fortress with falls | mid | 160px |
| Fire | flame-crowned keep | short range, fastest cadence | 171px |

A tower's role should be legible before its range ring is drawn.

## One more, for a dark element

Darkness needed a line the others did not: **a pale rim light, bright emissive cracks and
light-toned trim**, because it is the only tower darker than the sunlit grass it stands on,
and without them it reads as a hole in the board rather than a building.
