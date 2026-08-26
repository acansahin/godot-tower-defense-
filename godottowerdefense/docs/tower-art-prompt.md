# Generating a tower art sheet

The six element towers were painted one set at a time, each from a single generated sheet of
five tiers. The first pass used tall, element-specific silhouettes; after the Water redesign
all six were moved to the same broad, ground-hugging fortress language so they sit naturally
on the board.

The eleven **fusion** towers (six duals, four triples, Pure — see `Game.FUSIONS`) are the
roster this recipe is now being used for. Steam, Lava and Clay are painted; the other eight still draw the code
art. Read "Fusion sheets" below before generating one — the method changed in two ways.

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
banner sigil, the trim metal, the crystals. Keep the element identity in those materials and
effects; the structural shape follows the shared fortress progression below.>

<A CONTRAST OR CATEGORY NOTE, if this element has one — see "Per-element traps".>

EFFECT RESTRAINT: the <flame / water / spores / glow / floating stone> may occupy at most
the top QUARTER of the tower's height and must read as <contained in its basin>, not as a
<column / geyser / cloud / beam>. The building is the subject; the element is carried down
the rest of it by <cracks / channels / roots / gilding>.

Tier progression, broad and ground-hugging like the Water set, growing mainly in WIDTH,
layers and structural complexity rather than becoming a tall column:
1 <a low circular ring with one contained effect> 2 <a wider stepped bastion with channels>
3 <a broad central keep with two low side basins or pylons> 4 <a compact radial citadel with
flanking turrets and a broad stair> 5 <the grandest layered fortress, still squat, with a
larger contained effect and a lit archway>

CRITICAL REQUIREMENTS (the reference image cannot show these — follow them exactly):
- Transparent background (alpha), no ground plane, no scenery, no backdrop, no grass under
  the towers.
- NO drop shadow and no cast shadow — the game draws its own.
- PROPORTION LIMIT: each tower's total width must be roughly 0.95–1.55 of its height. The
  building should feel broad, but must not become a horizontal platform.
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

## Shared silhouette, distinct identity

The Water redesign established the shape that works on the painted board: a low circular
ring at tier 1, then wider stepped masonry, side structures, and finally a compact radial
fortress. The other five element sets now use that same progression instead of growing into
tall narrow columns. This shared mass makes the roster feel as if one culture built it and
keeps the sprites visually planted in the terrain.

Element recognition now comes from materials and contained effects rather than radically
different height-to-width bands: Fire is dark forge stone and orange flame, Earth is cool
quarried granite and amber crystal, Nature is roots and dark ivy, Light is pale stone with
slate accents and a restrained gold core, Darkness is charcoal masonry with violet cracks,
and Water is gray-tan waterworks with blue channels. Preserve those contrasts when making
duals; do not return to the old spire/obelisk silhouettes.

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

## Fusion sheets

Two things about the recipe changed when the fusion roster started being painted, and both
come from the game having moved on rather than from the art.

**Attach the WINDING board, not `board_source.png`.** A Standard run plays entirely on
`assets/art/maps/winding_forest_close_v1.png` (`main.gd` `STANDARD_BOARD`). `board_source.png`
is the spiral board, which nothing in a Standard run reaches any more. Attach the board the
tower will actually stand on.

**Attach the two PARENT sheets as well.** The original six only had to match the board. A
fusion has to match the board *and* the roster already on it, and it has to read as both of
its parents at a glance rather than as a muddy average of them — so attach
`_source_<parent>.png` for each element in the combination and ask the generator to take the
masonry and palette cues from them. Steam took the grey-tan waterworks and blue channels from
Water and the dark forge stone, iron and furnace glow from Fire, and it reads as both.

**Naming.** `Tower.art_key()` looks a fused tower's set up under the combination's FIRST name,
lower-cased, spaces to underscores — `steam_1.png` … `steam_5.png`, `flesh_golem_1.png`, and
so on. Never the per-tier name: one set of five files covers all five levels, exactly as an
element's does, and the tower still renames itself to Vapor and Immolation as it climbs. An
unpainted combination has no files, `Sprites.tower()` returns null, and the code art draws —
the same fallback that let the six element sets land one at a time.

**Let the silhouette step where the NAME steps.** A dual carries three names over five levels
(1-2 / 3-4 / 5) and a triple two (1-3 / 4-5). Asking for a visible structural change at those
exact tiers costs nothing and makes the rename land as something the player can see.

### What the Steam pilot measured

Generated in one pass from the template plus the two changes above, and it passed every
constraint the earlier sets had to be re-generated to meet:

| Check | Target | Steam |
|---|---|---|
| Ground anchor off its own centre | ~0% (shipped sets 47-52%) | 49 / 49 / 50 / 50 / 50% |
| Width : height | 0.95-1.55 | 1.09-1.15 |
| Canvas | 1774x887, 2:1 | exact |
| Thin effect above the masonry | under a quarter | top 12-15% |

One near miss worth carrying into the next ten: the prompt asks for **60 px** between towers
and the sheet came back with **40 / 40 / 49 / 39**. It cut correctly anyway — `cut_sprites.py`
splits on any fully empty column, and its `MIN_RUN` filters narrow INK runs (specks), not
gaps — but 39 px is close enough to nothing that a slightly wider tier-5 skirt would have
merged two towers into one sprite. Keep asking for 60.

### Checking a set landed, without hunting through a screenshot

`--fill-board` now prints an ART TALLY after its placement line: every set standing on the
board, how many of each, and `art*` / `art-` for whether `assets/art/towers` has the files.
A new set is two or three towers out of 47, and "is it painted?" was being answered by
zooming around a `--shot`. Read the tally first; take the shot to judge the art, not to find
it.

That line also exposed a harness bug the Lava pass tripped over: the element the harness
added when fusing was the first one the tower was MISSING in `Game.TOWER_ORDER`, so every
dual came out Steam, Well or Clay and every triple Rainbow or Infernal. Lava, Sun, Roots,
Dinosaur and Flesh Golem were never built at all — `--fill-board` could not have shown the
Lava art no matter how the sheet was cut. The scan now starts one past the base element and
rotates that start every sixteenth tower, which covers all six duals and all four triples.

### What Lava measured

Second fusion painted, generated in one pass from the template plus the two changes above
and the Fire/Earth trap notes. It needed no re-cut:

| Check | Target | Lava |
|---|---|---|
| Ground anchor off its own centre | ~0% | 48.8 / 50.0 / 49.8 / 50.3 / 50.0% |
| Width : height | 0.95-1.55 | 1.08-1.28 |
| Canvas | 1774x887, 2:1 | exact |
| Alpha | real transparency | RGBA, corners clear |

It runs WIDER than Steam (1.28 against 1.15 at the low tiers) because the caldera cone
flares at the foot, and it is the broadest set in the roster so far. Still inside the limit.

### What Clay measured, and the one constraint it missed

| Check | Target | Clay |
|---|---|---|
| Ground anchor off its own centre | ~0% | 49.8 / 49.2 / 49.3 / 50.0 / 49.4% |
| Width : height | 0.95-1.55 | 1.35 / 1.26 / 1.21 / 1.03 / **0.92** |
| Canvas | 1774x887, 2:1 | exact |
| Alpha | real transparency | RGBA, corners clear |

Tier 5 came back at **0.92**, just under the floor, and the shape of the miss matters more
than the number: the ratio falls monotonically across the ladder (1.35 -> 0.92), which is the
set growing UPWARD at the top tiers — exactly what the shared broad silhouette exists to
stop. The cause is the brief itself. Asking for a seated colossus at tier 5 asks for a
figure, and a figure is taller than it is wide. It was shipped as it is: the game scales to a
fixed HEIGHT, so a narrow tower takes less board rather than burying its neighbours, and at
board scale it reads correctly beside Steam and Lava. **Any future tier-5 built around a
figure needs the proportion written into the tier line, not just into the constraints list**
— say the colossus is SEATED AND WIDE, its knees and shoulders forming terraces wider than
it is tall.

The colour trap it was written to dodge worked. Clay was the roster's third grey building
waiting to happen; wet terracotta plus cyan channels separates it from Earth, Water and the
map in one step, and it does not collide with Lava either — Lava is near-black with orange
seams, Clay is warm ochre with cold water.

### Per-fusion traps

Each inherits its parents' traps from the section above, and adds its own.

- **Lava** (fire+earth) — fire's rule wins: the stone must be **dark**, or orange on the
  map's warm green and tan has nothing to separate it.
- **Sun** (fire+nature) — gold is the Light trap. Needs dark accents or it breaks the muted
  register. Nature's canopy ban also applies.
- **Clay** (water+earth) and **Well** (water+nature) — both land near the existing grey
  masonry. Clay especially: the roster's closest pair is already nature/earth, and Clay is a
  third grey building. Lean hard on the wet clay ochre and the blue channels.
- **Roots** (earth+nature) — the canopy ban **doubled**. The map is full of pine; a tower
  crowned with foliage reads as scenery, not as a building.
- **Rainbow / Spectrum** — the highest risk in the roster. Multi-colour against a deliberately
  muted board. Keep the prism desaturated and let the masonry carry the mass.
- **Dinosaur / Fossil** — must be a BUILDING with bone and fossil set into its stone, not a
  creature. Everything else in the roster is architecture.
- **Flesh Golem / Living Flesh** — red risks reading as an enemy. Keep it a fortress with
  veined stone, not a body.
- **Pure** — the strictest version of every Light rule: pale stone, prismatic core, and dark
  slate, shadowed arches and deep-set windows so it holds its edges against the pale road.

## Watch list

With every tower now built from the map's grey masonry, **nature and earth are the closest
pair in the roster**. They separate by growth, banner colour and earth's battered low-slung
walls, but if two towers get confused in play it will be these.

**Lava and Fire** are the third pair, and the one the Lava sheet had to fight: both are
orange-lit stone. They separate at board scale by VALUE, not hue — Lava is near-black basalt
with magma seams reaching all the way down to its foot, Fire is warmer brown stone whose
glow is concentrated in the brazier at the top. Fire also keeps its animated flame, which
nothing else has. A future fusion that wants orange must go darker than Lava or lose to both.

**Steam and Water** are the second pair to watch, and the first one the fusion roster
created: both are blue-topped stone. Steam separates by its copper pipework and the orange
furnace glow in its archway — at board scale that glow is doing most of the work, so no
future fusion should take Steam's copper-and-orange combination.
