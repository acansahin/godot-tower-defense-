# Generating a tower art sheet

The six element towers were painted one set at a time, each from a single generated sheet of
five tiers. The first pass used tall, element-specific silhouettes; after the Water redesign
all six were moved to the same broad, ground-hugging fortress language so they sit naturally
on the board.

The eleven **fusion** towers (six duals, four triples, Pure — see `Game.FUSIONS`) are the
roster this recipe is now being used for, and **they no longer follow the recipe above.**
Read "Fusions are named things" below before generating one: the six element towers keep the
shared fortress language, and every fusion now takes its shape from ITS OWN NAME instead.

EVERY tower in the game is painted, and every one of the eleven fusions now follows the NAME
rule: a `--fill-board` run reports `art*` on all fifteen rows, and none of the fusions is a
fortress any more. Steam is an engine, Lava a volcano, Clay a pit, Well a waterfall, Sun a
bronze disc, Roots a snare, Infernal a rift, Rainbow a prism ring, Dinosaur a fossil beast,
Flesh Golem a seated golem, Pure a plaza. The four ELEMENT towers keep the shared fortress
language and were not touched.

The pipeline around it is in [CLAUDE.md](../../CLAUDE.md) ("Painted tower set"); this file is
only the prompt.

## Attach the board. This is the whole method.

**Every prompt block below opens with its own attachment list, as full paths**, so a copied
prompt carries them and nothing has to be remembered separately. They are absolute for this
checkout — `C:\Users\alica\OneDrive\Belgeler\GitHub\godot-tower-defense-\godottowerdefense\`
— so if the repo moves, the prefix is the only thing to change. The ORDER in each list is
load-bearing: the prompts refer to the attachments as "image 1", "image 2", and so on.

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
[Attach this file:
   1. C:\Users\alica\OneDrive\Belgeler\GitHub\godot-tower-defense-\godottowerdefense\assets\art\board_source.png
   ^ for a FUSION sheet attach the WINDING board instead, plus both parent sheets —
     see "Fusion sheets" below for the three exact paths.]

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

## Fusions are named things, not fortresses

Six duals were painted to the recipe above — same broad ground-hugging progression, same five
tier beats, same lit archway and banner and top basin, "must read as BOTH parents at a
glance" — and the verdict on the finished board was that they are one mound dipped in six
colours. That is exactly what the recipe asks for, so it is the recipe that was wrong, not
any one sheet.

**The four element towers keep the shared fortress language. Every fusion now takes its form
from its own NAME.** Steam is a steam engine. Lava is a volcano. Dinosaur is a dinosaur.
The parent elements survive as MATERIALS AND PALETTE, never as silhouette, and the parent
sheets are still attached — relabelled in the prompt as "attached for their materials and
palette only, do NOT copy their shapes".

What is dropped: the five-beat tier script, the mandatory archway/banner/basin, and the
"reads as both parents" requirement. What survives untouched is everything with a measurement
behind it — transparent background, no shadow, symmetric footprint, effects inside the
silhouette, nothing floating, 60px gaps, one baseline, exact canvas, and the proportion rule.
That last one matters MORE here, not less: the game scales every sprite to a fixed HEIGHT, so
a tall subject is drawn with less mass than a broad one and reads as the weaker tower
regardless of what it costs.

### The plinth rule

Some fusions are now creatures — Dinosaur, Flesh Golem, and Clay's own Living Statue — and
the creeps walking past them are painted creatures too. So every named-form fusion stands on
**a low ruined stone plinth**, and that is the only element they all share. It does two jobs
at once: it says "planted building, not a walking enemy", and it gives `Sprites.anchor()`
the even bottom band it needs, which an organic shape does not have on its own.

Two more lines that come with a creature and not with a building: ask for a three-quarter
view with the head angled toward the viewer, because **the game's creeps are painted in
profile** and a profile pose reads as one of them; and ask for a settled, non-walking pose,
because towers never move.

### What Dinosaur measured, the pilot for all this

| Check | Target | Dinosaur |
|---|---|---|
| Ground anchor (measured as the GAME does) | ~50% | 49.0 / 47.5 / 49.1 / 50.3 / 47.8% |
| Width : height | wider than tall | 1.08 / 1.09 / 1.12 / 1.10 / 1.19 |
| Canvas | 1774x887, 2:1 | exact |

It works: on the board it is plainly a different KIND of object from the towers beside it,
which is the whole point of the change, and it does not read as a creep. The name ladder
earns its keep too — Dinosaur at tiers 1-3 and Fossil at 4-5, so the tower petrifies at the
rename and the player can see it happen.

**Measure the anchor the way `Sprites.anchor()` does, or the number is fiction.** A first
pass over this set reported 46.0-54.0% and concluded that creature shapes simply cannot hold
their centre. They can: the game takes the MEDIAN of the row middles across a band 4% of the
sprite's height, and by that measure Dinosaur sits at 47.5-50.3%, no worse than the fortress
sets. The bad number came from averaging the lowest four rows, where a single tapering corner
of the plinth dominates. A one-off script is fine, but copy the algorithm from `sprites.gd`.
### What Steam measured, repainted as an engine

The first Steam was a blue-topped stone keep with copper pipework — a fortress wearing the
word. Repainted under the name rule it is a riveted boiler bolted to a stone plinth: firebox
glowing orange behind its grate, copper condensers, matched flywheels, stubby stacks jetting
steam, and at tier 5 the whole machine run past its limit, seams glowing red and every valve
lifted. On the board it reads as a MACHINE at a glance, which no amount of recolouring the
old keep would have achieved.

| Check | Target | Steam |
|---|---|---|
| Ground anchor (as the game measures it) | ~50% | 48.1 / 55.9 / 54.8 / 53.4 / 52.0% |
| Width : height | wider than tall | 0.94 / 1.04 / 1.12 / 1.12 / 1.13 |
| Canvas | 1774x887, 2:1 | exact |

**An off-centre anchor is only a defect when the BASE is uneven.** Steam's reads 52-56%, the
highest in the roster, and it is harmless: the plinth is even, and what pushes the number is
the steam plume widening the sprite's bounding box on one side while the ground point stays
where it is. The game positions by the anchor, not by the box, so the machine lands on its
spot and the plume simply hangs further out on one side. Compare Earth's original 17%, which
was a rock apron on one side of the FOOT and did move the building off its spot.

Tier 1 came in at 0.94 wide to tall, a hair under the floor, for the same reason in the other
axis — a tall plume over the smallest engine. Not worth a re-cut at that size.

### What Lava measured, repainted as a volcano

The cleanest set the pipeline has produced: anchors 49.5 / 50.0 / 49.8 / 49.9 / 49.2%, every
tier wider than tall at 1.18-1.31, canvas exact, cut in one pass. A live cinder cone with a
molten crater and lava rivers, held in a low kerb of heat-blackened carved blocks.

The kerb is the volcano's version of the plinth rule, and it earns its place twice over: it
says a built thing rather than a boulder on a board already full of rocks, and being a plain
even ring it is the reason the anchors are the best in the roster. **Where a named form has no
natural symmetry, give it a symmetrical thing to stand in.**

### What Rainbow measured, the one the board was least able to take

Anchors 50.2 / 49.6 / 47.9 / 49.6 / 50.9%, every tier wider than tall at 1.18-1.35, cut in
one pass. A ring of clear crystal slabs standing in a plain stone kerb with a low wide arc of
split light across it — the same kerb trick as the volcano, and the same clean anchors.

Multi-colour on a deliberately muted board was the standing risk in the roster, and what
defused it was saying WHERE the colour may live rather than how much of it there may be:
desaturated watercolour bands, and stone and crystal that stay COLOURLESS so the eye reads
grey masonry plus one soft arc. It is now the brightest thing on the board and still in
register. Asking merely for "muted colours" would have tinted the whole tower and lost it.

### What Infernal measured, and the shape that separates it from Lava

Anchors 47.9 / 54.4 / 51.0 / 49.2 / 50.0%, every tier wider than tall at 1.25-1.47, cut in
one pass. A rift torn open in the ground inside a fallen ring of blackened blocks, chains
staked across it, crimson light welling up out of the split.

This one shares two elements with Lava and had to stay apart from it, and under the name rule
the separation is FREE — the two names are different things, so the two silhouettes are
different things. Lava is a cone that rises; Infernal is a hole that sinks. On the board they
sit side by side and read instantly, which the old recipe could only have attempted through
hue, since both would have been broad stone mounds. **Where two fusions share elements, the
name rule does the work that a colour note used to have to do.**

Its first attempt, generated before the name rule, is the cautionary one in this file: a
stepped elemental cone with rocks hovering around an orb, measuring 0.91 down to 0.69 wide to
tall with 20-37% of each sprite spent on floating debris. Both defects are now named in every
prompt.

### What Flesh Golem measured: keeping a creature off the enemy side of the board

Anchors 48.1-51.0%, every tier wider than tall at 1.16-1.23, cut in one pass. A hunched golem
of granite boulders bound in dark red sinew, rooted into a stone plinth, the flesh taking over
from the stone at tier 4 where the name changes to Living Flesh.

Its old trap note said red risks reading as an enemy, and under the name rule the tower IS a
creature, so the risk went up rather than away. Three lines hold it: the plinth, the ban on a
profile pose (the creeps are painted in profile), and a colour instruction that says the red
is a MINORITY of the surface, living in the seams between grey stone and moss. Deep liver red,
never bright, never pink, never glossy. On the board it reads as a boulder pile that happens
to be alive, which is the right side of the line.

### What Pure measured, the last one

Every tier wider than tall at 1.21-1.36, cut in one pass. A wide sunken plaza of concentric
steps, four elemental channels running inward from the rim, and where they meet, one white
light. The disc IS the plinth here, which is why it is the flattest tower in the roster.

Anchors 41.9 / 49.0 / 49.0 / 48.4 / 50.1%. Tier 1 is the worst single figure any sprite has
measured, and it is worth knowing why: a plaza drawn in perspective is an ELLIPSE, and an
ellipse's lowest point sits at its front — which on this one is front-LEFT rather than
front-centre. The 4% band `anchor()` reads is only seven rows on a 164px sprite, so it lands
entirely inside that narrow tip. By seven rows higher the middle is already back at 48%. It
is about six pixels at drawn size and only on the smallest tier, so it ships; a set built on
a big flat disc is where to expect it.

The pale-on-pale trap was the other risk and it held: dark slate at the rim, shadow in every
cut step, black seams between flagstones, and white light confined to a thin seam and a pool
at the centre. It sits on the map's pale road without dissolving into it.

### What Clay measured, and the time the NAME had to move instead of the art

Anchors 54.5 / 49.8 / 50.3 / 50.0 / 50.0%, every tier wider than tall at 1.17-1.36, cut in
one pass. A wide sunken pool of wet ochre clay in a kerb of rough stone and timber, teal water
fed in through cut channels, plank walkways and matching racks of drying bricks around the rim.

The first attempt at this repaint WAS a golem, because `Game.FUSIONS` renames this tower to
"Golem" at level 3 and "Living Statue" at level 5 and the name rule points straight at that.
It was rejected on sight, and correctly: the roster already has Flesh Golem seated on a
plinth, and two golems is one too many.

**When the name is the problem, move the NAME.** The tower is now a worked clay pit — earth
plus water with no figure in it at all, and its slow reads as mud rather than as an ability —
and `Game.FUSIONS` renames the ladder Clay -> Clay Pit -> Great Mire. Those three words are a
deliberate departure from the source map, marked in `game.gd` and counted in CLAUDE.md beside
the other three; the recipe, the stats and the ability are untouched. Worth remembering the
next time a ported name and a good silhouette disagree: the names are three strings, and the
art is a tower the player looks at for a whole run.

### What Sun measured, repainted as an object

Anchors 46.8 / 51.9 / 51.2 / 51.0 / 50.1%, every tier wider than tall at 1.16-1.40, cut in
one pass. A thick convex disc of patinated bronze tilted back in a squat stone cradle, its
relief channels glowing amber from within, flanked by matching smaller discs on a terraced
plinth.

The old Sun was not wrong so much as GENERIC: after the roster turned into an engine, a
volcano, a rift, a clay pit, a dinosaur, a golem, a crystal ring and a plaza, it was the last
plain fantasy building left. Its replacement had to dodge two towers rather than one, since
Rainbow and Pure are both already "a ring with light in it", so the brief made it SOLID METAL
instead of crystal, ONE big object instead of a ring of small ones, and steady heat instead
of a pale arc. Attaching the Rainbow sheet with "this asset must NOT look like it" is the
same trick Clay used against Flesh Golem, and it is now the standard way to separate two
towers that would otherwise converge.

The gold trap held the way it always has to: aged bronze over most of the disc, dark slate in
the cradle, ivy on the terraces, and gold only as a thin edge on the relief plus the glow in
the cut channels. And no flame anywhere, which is what keeps it apart from Fire.

### What Well measured, repainted as a spring

Anchors 49.5-52.4%, every tier wider than tall at 1.06-1.31, cut in one pass. A mossy well
head that becomes a clear teal spring welling between wet boulders and finally a broad low
waterfall, with a dark timber wheel turning in the outflow.

The old Well was a spring-HOUSE — roofs, walls, a lit archway — because it was written to the
five-beat template. Its name ladder was pointing somewhere else the whole time: Well, Spring,
Waterfall is a route from a dug hole to a natural feature, and there is no building anywhere
on it. The repaint follows the ladder and the board gains its second waterfall, which is a
good thing rather than a collision: the map already has one on its left edge, so the tower
looks native to it.

Clay went into the prompt as the do-not-resemble sheet, since both towers are a pool in a
ring: opaque ochre mud in cut stone and timber against clear teal water over natural wet
rock. **A tier-5 waterfall also has to be asked for as a WEIR** — wider than it is high —
or the name walks the set straight into a tall cascade and the proportion rule.

The water wheel survived the repaint. Nothing in the code reads it, but it is the only visual
the attack-speed aura has, and a turning wheel says haste more plainly than any amount of glow.

### What Roots measured, the last repaint

Anchors 48.7-50.5%, proportions 1.19-1.54, cut in one pass. A wide low nest of bare knotted
roots and thorn-hoops coiled around a dark hollow, lifting slabs of cracked granite as it
spreads.

Roots was already close to its name — the old set was a root mass too — so the gain here is
the smallest of the six repaints, and it is a useful measure of what the name rule actually
buys. What changed is that the building parts went: the lit archway, the stone stair, the
ruined-bastion skeleton it inherited from the five-beat template. The name ladder never
mentioned a building; Roots, Brambles, Entangling are three words about what the PLANT DOES,
and once the thorn-hoops and the coiled snare became the subject, the tower reads as the trap
it is rather than as a fortified mound with plants on it.

The canopy ban stayed doubled and specific, and the sheet obeyed it: bare wood and thorn, the
only green a near-black bramble darker than the map's grass. On a board that is mostly pine
and undergrowth, that is the whole difference between a tower and a bush.

### A cutter bug this sheet found

`cut_sprites.py` applied its `MIN_RUN` speck filter to every run of ink that ENDED inside the
image, and not to the one still open when the sweep reached the edge. This sheet arrived with
a 37x15 speck touching the bottom edge, so the tool reported a second ROW — which on a
single-row sheet silently renames every sprite (`extra2_1.png`, `extra3_1.png`, …) and caps
them all at one height — and stretched tier 5's bounding box from 396 to 640 px tall, which
would have drawn that tier at 60% of the size of the others. Both edges now take the same
filter. The speck itself was erased from the stored `_source_dinosaur.png`.

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

### What Sun measured: the fix for Clay's miss, and how to use a motif reference

| Check | Target | Sun |
|---|---|---|
| Ground anchor off its own centre | ~0% | 49.2 / 51.3 / 49.5 / 49.7 / 49.8% |
| Width : height | 0.95-1.55, wider than tall | 1.17 / 1.19 / 1.19 / 1.31 / 1.12 |
| Canvas | 1774x887, 2:1 | exact |

Clay's tier 5 came in at 0.92 because the tier line asked for a colossus and said nothing
about its shape. Sun's prompt puts **the proportion inside each tier line** — "about 1.35
times as wide as it is tall", per tier, counting down to 1.15 at tier 5 — instead of leaving
it to the constraints list at the bottom. Every tier came back wider than tall, tier 5
included. Do this for any set whose top tier is built around a figure, a sphere or a spire.

**A motif reference is attachable, but only for its ORNAMENT.** Sun started from a picture
the designer liked: one tall golden temple crowned with a floating armillary sphere. It was
installed in the game as-is to find out, and the answer was measured rather than argued —
0.55 wide to tall, against a roster sitting at 1.08-1.28. Because the game scales sprites to
a fixed HEIGHT, that spends the whole height budget on a needle: beside Water, Fire and Clay
the building looked half their mass, and its filigree turned to mush at board scale. The
motif survived, the silhouette did not. The prompt that worked attaches the picture with an
explicit instruction to take its ornament vocabulary (armillary rings, sun disc, slate roofs,
gold trim, ivy) and to ignore its proportions, detail density and glossy rendering, ending
"where the reference and the board disagree, THE BOARD WINS". The armillary went from
floating above the tower to lying FLAT in the top terrace like an orrery on a table.

Worth keeping: **install a candidate and photograph it** before arguing about it. Copying one
image over `sun_1..5.png`, importing, and running `--fill-board --shot` takes a couple of
minutes and settles the question in a way no description of a constraint does.

### What Well measured: three neighbours named in the prompt, and an anchor that drifted

| Check | Target | Well |
|---|---|---|
| Ground anchor off its own centre | ~0% | 46.7 / 51.0 / 48.1 / 49.1 / 53.2% |
| Width : height | wider than tall | 1.19 / 1.15 / 1.18 / 1.09 / 1.10 |
| Canvas | 1774x887, 2:1 | exact |

Well is the first fusion with THREE towers it could be confused with rather than one, and
the prompt names all three and says what to withhold from each: not Water (grey-tan stone,
bright blue channels) so its own water is deep teal-green in mossy green-grey stone; not
Steam (copper pipework, orange furnace glow) so it carries no copper, no brass and no orange
anywhere; not Clay (warm terracotta) so it carries no warm ochre at all. Naming the tower to
avoid AND the specific material to drop is what makes that work — "make it different" does
not survive contact with a generator.

Its per-tier proportions held (1.09-1.19, all wider than tall), but the ground anchor spread
46.7-53.2%, the widest of any set so far — Steam, Lava and Clay all landed inside 48.8-50.3.
The cause is not the foot, which is symmetrical as asked, but the FLANKS: tiers 4 and 5 carry
a mill house on one side and a smaller shed on the other, and tier 1 a lantern post on one
side only. `anchor()` reads the middle of the sprite's lowest band, so unequal side buildings
shift it even when the base is even. At the drawn size that is about four pixels, which is
why it shipped; a set that wants flanking structures should be asked for them in MATCHING
PAIRS.

The attack-speed aura got a visual for free: a turning water wheel. Nothing in the code reads
it, but a tower that hastens its neighbours reading as a mill is worth more than another
basin.

### What Roots measured: inverting the material instead of shifting the hue

| Check | Target | Roots |
|---|---|---|
| Ground anchor off its own centre | ~0% | 53.0 / 49.8 / 48.8 / 47.9 / 51.0% |
| Width : height | wider than tall | 1.24 / 1.19 / 1.35 / 1.17 / 1.21 |
| Canvas | 1774x887, 2:1 | exact |

Roots landed in the most crowded corner the roster has: Nature, Well and Sun are all green
growth on grey stone before it arrives. Clay and Well were separated by shifting the HUE,
and there was no unused green left to shift to. So this one inverts the MATERIAL instead —
in every other tower the masonry is the mass and the growth is the accent, and here the wood
is the mass and the ruined granite shows through it in broken courses. Prompt line: "the mass
is the WOOD, and the ruined masonry shows through it".

The canopy ban had to be doubled and made specific to survive that. Not "avoid a canopy" but
**no leaves and no foliage of any kind** — bare wood, thorn and briar, with the only green
permitted being a near-black bramble darker than the map's grass, and a knot of bare roots
where a crown would go. It reads as a building on the board and not as a bush, which was the
whole risk; the lit archway and the stone stair are what carry that.

Anchors spread 47.9-53.0%, the same failure mode Well had — asymmetric flanks rather than an
uneven foot, even with matching pairs asked for. Take the pairs request as reducing the
spread, not removing it: on a set built out of irregular organic shapes there is no symmetry
to hold onto in the first place.

### Per-fusion traps

Each inherits its parents' traps from the section above, and adds its own.

- **Lava** (fire+earth) — fire's rule wins: the stone must be **dark**, or orange on the
  map's warm green and tan has nothing to separate it.
- **Sun** (fire+nature) — gold is the Light trap. Needs dark accents or it breaks the muted
  register. Nature's canopy ban also applies. PAINTED: pale sandstone held down by dark slate
  domes and dark ivy, gold only as trim, and no open flame anywhere — that last one is what
  keeps it apart from Fire, which is dark stone with a lit brazier.
- **Clay** (water+earth) and **Well** (water+nature) — both land near the existing grey
  masonry. BOTH PAINTED, and both solved by hue rather than by shape: Clay took wet ochre
  terracotta with cold cyan channels, Well took mossy green-grey stone with deep teal-green
  water, a dark timber wheel and no copper anywhere. Steam's copper-and-orange stays reserved.
- **Roots** (earth+nature) — the canopy ban **doubled**. The map is full of pine; a tower
  crowned with foliage reads as scenery, not as a building. PAINTED: the ban was written as
  "no leaves and no foliage of any kind", bare wood and thorn only, and the tower inverts the
  roster's material — the WOOD is the mass and the ruined granite is the accent.
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
