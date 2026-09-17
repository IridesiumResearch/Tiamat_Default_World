# Engine asks from the Spindle

What the world mod has needed from the engine, found by building it. Each
entry says what was seen, why the mod cannot fix it, and the smallest
engine change that would. Newest first. Items are removed when they land.

*Landed 2026-09-10: the merge write (`set_block(pos, block, mask, { merge
= true })`, contract §7.4 — no protocol change, it is the placement rule
made reachable), the serve budget (53296a0), `Density:bounds` (9f01f67),
and maps <-> density fields (86cd44e). The mod uses the merge write for
every runtime structure, the bound for its gate, and clamps its noise so
the bound is tight; the map node is the erosion work's. Items 0, 1, 2 and 4
below are closed and kept for the record. Item 3 — structures at
generation across chunk edges — is the one still open; note from the
engine that `buf:set_subnode` already preserves a uniform block's other
cells, so generation-time embedding needs nothing new, only the
cross-chunk pass.*

*Landed 2026-09-17: **34, a layered fill evaluated the terrain where none
of its layers paints** (engine 92267e7). `fill_layers` now checks the code's
bound, then the code, and evaluates the terrain only where some block's code
matches one of that call's layers. Two rules come with it, and this mod
follows both: keep a biome's code field cheap and low-frequency, so the
bound decides most chunks for free; and keep `code = -1` bands out of a
biome's call — ANY matches everywhere and forces the evaluation — so the
generator lays the body's two wildcard bands in a call of their own.*

*Landed 2026-09-16: **31, a fluid gives no light** (engine b6935c3). A
fluid now gives off the `light_emit` of the block it is drawn as, and
declares its own `opacity`. The mod's lava is opaque and lights its pits:
measured headless on a generated lava block, `r15 g8 b1` in it and `r14`
two blocks over its surface. The magma shell is still the look-alike solid.*

## 30. A program cannot spend the same value twice (2026-09-16)

**The binding constraint on the whole world.** A density program may hold
1,024 operations and eight live buffers, and the shore programs are at
985 (`temperate_shore`) and 939 (`belt_shore`) with three biomes' terms in
them. Nothing in the compiler remembers a subtree it has already emitted,
so every helper the mod calls twice is compiled twice:

- `shape.ring` re-emits the radius — `x*x + z*z`, the wobble noise, the
  fold — at every call, and the mod's own comments already say the radius
  is "three buffers of its own".
- the reef's `out()` is a map read and a clamp, and the shore program
  contains six copies of it;
- the dunes' barchan is one stretched noise read by two clamps, so the
  noise is in the program twice;
- every `a * (1 - w) + b * w` cross-fade emits `w` twice.

What that costs, today, in the world: the reef's tidal gutters had to stop
being a cut in the terrain and become a surface material instead; the
reef's floor is a `max` against the shelf rather than a cross-fade into
it; the Coastal Cliffs' blowholes and their fine rib are still out (2.4,
2026-09-15); and the rim is bare past about 54 km because the chunks there
need the body test as well as the terrain, which is why the mod keeps a
second, thinner family of programs (`P.flank`) with none of the biome
terms in it — with room, that family would not have to exist.

**The smallest change is reuse, not a bigger cap**: hash-cons identical
subtrees when `game.density` compiles, emit each once, and have the
repeats read the buffer it went to. The mod builds the repeats out of the
same node constructors with the same arguments, so structural equality
catches nearly all of them. The honest catch is that a shared value has to
stay live between its uses, so reuse trades operations for buffers — which
is why this ask is really "either more of one or more of the other": more
buffers with spilling, or the cap raised, or both. Any of the three buys
the same thing, which is that a biome can carry the detail its brief asks
for without another one losing some.

## 33. A chunk tint cannot brighten (2026-09-16)

**Seen.** The designer's rule is one grass, one dirt, one lichen, and a
biome that wants them another colour gets it from its chunk tint. The
Savanna's grass should be gold and the Taiga's rust; the one grass is a
mid green, and the tint multiplies it with every channel clamped to 1
(`tint_bytes`), so the best a tint can do is darken green toward olive.

**Why the mod cannot.** A brighter base texture would brighten every biome
that does not tint, and the untinted world is most of it.

**Ask.** Let a chunk tint's channels run above 1 — 0 to 2 in the byte, say,
with 1.0 at 128 — so a tint can lift a channel as well as cut one.

## 32. A cover fill is one block tall (2026-09-16)

The Flower Forest's brief asks for "single- and TWO-block flowers", and
alliums and peonies are the two-block ones. `fill_cover` clamps its run to
`SUBNODES_PER_AXIS` and keeps it inside one block, so the tallest flower
the mod can grow is three cells — a third of the height the brief wants,
and the same height as a poppy, which should be the short one.

Everything else the mod has for standing things on a surface is the
scatter, and a two-block flower through the scatter is a schematic per
flower, a stand program per flower, and a neighbourhood pass per chunk for
what a cover does in one pass — for a plant that grows every few blocks
across a whole ring, that is the wrong tool by an order of magnitude.

The ask is a cover that may run past the block it starts in: `cells`
allowed over three, the run continuing into the block above while the
blocks are empty, and the run stopping where it meets anything. The
engine already finds the surface and already keeps one run to a block, so
this is the same scan with the ceiling lifted.

## 27. Friction per block (2026-09-14)

The Frozen Wastes' crevasses have "slick, near-frictionless blue ice
walls", and ice underfoot should slide. Nothing in `register_block` says how
a body grips a block, so ice walks like stone. A `friction` on the block —
a share of the normal grip, default 1 — read by the movement code for the
block under a body and the block it is pressed against, is the ask.

## 29. A plant's cells displace the water round it (2026-09-15)

"Grass, when under water, should get saturated so it doesn't have an air
bubble around it." A block's fluid volume is twenty-seven cells less the
cells it holds, and a tuft of grass, a water iris, a stand of seagrass or
kelp holds one to three, so the water round a plant is short by that much
and the plant stands in a pocket of air. A passable (or billboard) cell
should not displace fluid: the block would hold twenty-seven of water and
the plant, drawn in it. The mod cannot do it — a fluid and a solid cannot
share a cell in the store — so its land covers keep out of the water
meanwhile, and the sea's own growth stands in pockets.

## 28. Summaries carry no fluid (2026-09-15)

The seas are placed: a third of the disc, in pools. A chunk outside the
detail radius is drawn from its summary, and a summary holds materials
only — so from a hill a sea is its floor, a hole in the world the shape of
the pool, until the player is within the detail radius and the full chunk
with its fluid arrives. A summary that carried "and fluid to this level"
(one level and one fluid per summary would do: a pool is flat) would draw
the sea to the horizon. Seen from the window at the first seas, with the
water inside the detail radius drawn in light mode 3 as one translucent
volume with the chunk seams visible through it, which may be the same
thing seen from inside.

## 26. A deep sea is heavy to load (2026-09-14)

**Seen.** The deep ocean put everywhere, headless, one bot: 213 of the ticks
in ninety seconds ran over budget, and the log put the fluid tick at 45 to
100 ms of each. The sea is 60 to 120 blocks deep, and its trenches 350.

**Why, from the code.** `Fluidics::chunk_loaded` touches every non-empty
block of a loaded chunk's fluid layer ("milk saved mid-flow has to carry on
flowing"), so a chunk of open sea puts 4,096 blocks in the solver's active
set, and a player's view of ocean is hundreds of such chunks. Each is found
settled and dropped, but finding it is the cost.

**Ask.** A generated or saved layer that is known to be at rest should not
be woken whole: only its blocks next to something that can move (air
beside a partial surface, an unloaded neighbour becoming loaded, an edit).
The designer is working in the fluid code now; this is the number to watch.

## 25. Light in water (2026-09-14)

The deep ocean's brief has "total light extinction" on its plains, a
hundred blocks down. Water is `transparent` and a fluid is a layer over air
blocks, so sunlight falls through a hundred blocks of sea at full strength.
A fluid that attenuates the sun — `light_falloff` on `register_fluid`,
levels lost per block of it — would make the deep sea dark and a shallow one
bright, which is the whole of it. Until then the plains are dark only in
that nothing grows on them.

## 24. Shade under a canopy (2026-09-14) — the chunk-arriving half LANDED (engine deba305); foliage still passes light as glass

**Seen.** The rainforest's brief has its canopy block 85-90% of direct
sunlight. Headless, round one spot 85% of the floor has a WHOLE leaf block
somewhere over it, and most of those columns read `sun = 15` at the floor.

**Why, from the code (not changed):**

1. **Foliage passes light the way glass does.** `see_through_from_rules`
   (`crates/server/src/light.rs`, about line 558) puts every `cutout` rule
   in the see-through table — "Contract §8.2: foliage passes light the way
   glass does" — and `Lit::faces` answers `Faces::OPEN` for a uniform block
   of it. Straight-down sun at 15 never attenuates
   (`crates/core/src/light/propagate.rs`, `arriving`), so any depth of
   leaves is open sky. Every leaf node in the world mod is `cutout`.
2. **A chunk loaded ABOVE a lit one never darkens it.**
   `Lighting::chunk_loaded` relights only the new chunk; `relight` clears
   only that chunk and `flood` only brightens; `remove` runs only for
   edits. `sky_reaches` counts an unloaded block above as open sky. The
   floor loads first (it is nearest the player), takes full sun, and keeps
   it when the canopy's chunks arrive. This is a bug whatever foliage does.

**Ask.** (2) first: when a chunk arrives, run the sun channel's removal
from the bottom layer of the new chunk into the chunk below wherever the
new chunk's bottom is darker than 15, and re-flood. For (1), a decision
for the contract: foliage that attenuates the sun by a level or two per
block rather than passing it untouched, so a thick canopy is dim beneath
and a thin one dappled. The mod cannot work round either: an opaque
material inside every clump would be visible through the leaves' holes,
and would still be undone by (2).

## 23. Fog by place (2026-09-14) — LANDED (engine 55e929d): the Taiga's mist uses it (2026-09-15)

The rainforest's brief asks for "persistent humid ground fog or mist" and
"deep emerald twilight" under its canopy. Fog is the sky's: `register_sky`
keyframes set one distance fog for the whole world by time of day, and
nothing sets it by place. A per-chunk answer like `register_chunk_tint` —
a fog colour and density for the columns of a chunk, blended across chunk
corners the way the tint is — is the ask; the mod would return a thick,
low, green-grey fog for the rainforest's chunks and nothing elsewhere. A
low-lying fog (thicker under a height over the ground) would be the ground
fog exactly. Until then the canopy's own shade and a darker emerald chunk
tint are all the twilight there is.

The rainforest also wants ambient DRIPS from the canopy and drifting MIST
particles, which are item 20. Its shade is item 24.

## 22. A noise stretched along one axis (2026-09-14) — LANDED (engine 12bd662): the badlands' rills, the mesa's wall ledges, the Frozen Wastes' dunes and sastrugi, and the Dunes' barchans (2.5) are all stretched noises

A cliff's roughness is not the same shape in every direction: rock flutes
and weathers vertically, strata run horizontally, and a noise that is
round in every axis reads as lumps. `Op::Noise` samples at `(x, y, z)`
with one frequency, so the only way to make a feature taller is to make it
wider by the same amount. A per-axis scale on the noise node — sample at
`y * y_scale`, default 1 — is the whole ask, and the bounds path scales
the same interval. `FractalParams` is built in thirty-one places, so the
field belongs on `Op::Noise` (or its own stretched variant) rather than in
the params.

The coast works round it: the cliff's vertical structure is `contour`
ribs, which are constant in y by construction, and the one term that does
vary with height is coarsened in every axis to stretch it.

## 21. The world seed in every VM (2026-09-13) — LANDED (engine fec84db): `/tp` samples biome fields with it

Terrain generates off the tick now, in worker VMs, and the seed arrives
there on each generator call's `pos`. The main VM never sees it: no hook
that runs there — ticks, joins, digs, random ticks — carries the seed, and
the chunk tint is asked in the workers as well. The mod's spawn aim
(`shape.ground_at_column`, `Density:at` with the seed) needs it on the
main thread, and so will anything that samples a field at runtime. A
`game.world_seed` integer set in every VM when the world opens — beside
`set_fluid_ids`, in `handle.rs` and `worldgen.rs` — is the whole ask; the
mod reads it already.

A client built before fec84db runs its own server without it (2026-09-14:
`/tp mesa` answered "the seed is not known yet"), so `/tp` falls back to
searching by landing when `game.world_seed` is nil.

## 20. Particles (2026-09-13) — LANDED as `game.emit_particles` (engine 985997a): the Ember Ridge's fumaroles vent steam off their sulfur (2.3, 2026-09-15). The blowholes and the canopy's drip are still to do in the mod

The coast's blowholes should erupt with sea spray, and nothing in the API
emits a particle: a burst of short-lived sprites at a position, in a
colour, with a velocity and a lifetime, spawned by a mod on a tick. Until
then a blowhole is a shaft with the sea at the bottom.

The rainforest (2026-09-14) wants the same thing twice over: drops falling
from the canopy's underside now and then near a player, and slow drifting
mist over its floor.

## 19. One terrain evaluation for many materials (2026-09-12) — LANDED twice: `fill_palette` (engine 44e7790, one value against thresholds) and `fill_layers` (a code per block and depth bands, this tree); the alpine surface uses the latter

**Seen.** An alpine chunk takes fifty milliseconds and more to generate,
past the whole tick's budget, every tick a chunk is served. The chunk
runs eight surface fills and a cover, and EVERY one re-evaluates the
terrain program — six octaves of noise a sample — because a fill is one
program and one material, and the material's condition is a band of the
terrain plus its own patch noise. Ten evaluations of the same field.

**Why the mod cannot do it.** A program cannot name another's result; a
subtree used twice is evaluated twice (no dup, no memo). The mod has
already cut what it can: fewer fills, fewer octaves in the terrain, the
world's detail left out under the alpine map.

**Ask.** A fill that maps ONE program's value to a table of materials:
`buf:fill_palette(field, { { low, high, material }, ... }, options)` —
the field evaluated once per sample, each cell taking the material whose
range its value falls in, or left as it was. A mod then writes its
surface as one program whose value is a code: the depth band of the
terrain and the patch noises combined into a number, `max` over layers of
a code times a clamped condition, with the later layer the larger code.
The alpine surface would be two programs (the terrain's solid and stone,
and the palette) instead of ten, and the chunk five times cheaper.
Failing that, a per-generate cache keyed by program identity would help
less and cost nothing in the API.

## 18. A fluid fill by heightmap (2026-09-12) — LANDED another way, for the rivers: `buf:fill_fluid_terraced{ level, within, fluid, lip }` (engine 81ba792, 2026-09-14) takes the level as a density read per column and holds a sloping body up with lips; the alpine lakes could use it with a flat level per lake, and still hold the water block

**Wanted.** Frozen lakes on the alpine valley floors: an ice sheet with
water under it, each lake at its own level. The floors are a map, so a
lake's level is a value in that map.

**Why the mod cannot do it.** `buf:fill_fluid_below(level, fluid)` takes
ONE world height per call — a sea level — and a mod cannot read a map's
value at a chunk (`Map:heightmap` is opaque to Lua; charter rule 4). So a
lake's level cannot reach the fluid fill, and the lakes hold the `water`
BLOCK under their ice instead of the fluid: it looks right through the
ice and digs as water, but it does not flow.

**Ask.** `buf:fill_fluid_below(heightmap, fluid)` accepting a
`Tiamot.Heightmap` as well as a number: every column filled up to its own
height, the counterpart of `fill_below_heightmap`. `Map:heightmap(pos)`
already produces the argument. With it the lake water is one line and
real.

## 17. The world cannot be read inside a dig or place hook (2026-09-11)

**Seen.** `game.get_block` returns nil from inside `register_on_dig_complete`
for the very block being dug, with the player standing on it. The block
reader answers through the sight lease (`mlua_vm.rs`, `block_reader`),
which is held only while the tick runs the mods' own callbacks; the dig
hook is asked from the dig path, where the lease is `None` and every
reading is `Unavailable`.

**Why it matters.** A hook that decides by what the block HOLDS — blooms
on a bush, a lock on a door, a nest with eggs — cannot look, and the
event carries one material of a block that may hold three. The mod
decides on the event's material and reads the block a tick later, which
means cancelling a dig it may then find had nothing to pick.

**Ask.** Hold the sight lease across the cancellable hooks, or hand the
dig hook the block's cells. Reads are the only thing wanted; a write from
a veto hook is already refused, and can stay refused.

## 16. A right-click on a block (2026-09-11)

**Wanted.** Picking roses: right-click a bush and it gives a rose or two
and loses its blooms for a while. Right-click is the natural verb for
"use what is in front of you" and the designer asked for it by name.

**Why the mod cannot do it.** Right-click is the place control, and a
placement exists only when the player carries a placeable material:
with an empty hand the client sends nothing, and `register_on_place`
never fires. `register_on_punch` is entities; `register_on_action` has
no target. The mod picks on a DIG for now — a completed dig on a bush
with blooms is cancelled with `""` and handled — which is the same idiom
`tiamot_default_life` forages berries with, but it is not the verb asked
for, and a pick that takes a dig's countdown is slow.

**Ask.** `game.register_on_use(callback)`: fired when the place control
lands on a block and no placement is possible (empty hand, or an item in
it), with `{ player, x, y, z (the cell), material, held }`, before
anything else; the same return ladder as the other hooks, `""` meaning
handled. The client already knows the cell under the crosshair — it is
what it would step across for a placement — so it is one message with
the target and nothing to place.

## 15. A cover fill (2026-09-11) — LANDED (engine ffac6e0)

**Wanted.** Grass that stands on the surface, is at most two cells tall,
and never crosses into the block above — the designer's "no stacking":
a tuft that is two blocks highlights and digs as two things.

**Why the mod cannot do it.** A field has no notion of the block a
sample is in (there is no `floor`), and even with one it would not
help: the engine samples a block at its bottom corner, so a run confined
to a block contains the block's one sample point in a third of columns,
and the sampled fill's surface-shell test — built from those samples —
would miss the rest in stripes along the contours. Only the buffer knows
where its surfaces are.

**Landed.** `buf:fill_cover(material, { cells = n, take = density })`:
for every empty cell on an occupied one, where `take` is positive there,
a run of up to `cells` cells inside that block, never overwriting a
cell, never standing on a run it wrote. `take` is evaluated at cell
resolution only in blocks that hold a surface. Two tests in `buffer.rs`;
the stub documents it. The tufts are now a `cover` entry in each biome's
fill list, run after every biome's fills, with a take field of the tuft
noise and a term keeping it within a sixth of a block of the ground, so
cave floors get none. The mod's sampled fill and its per-cell band are
gone with it: cheaper, and exact.

## 14. Sprites are never drawn in play (2026-09-11) — FIXED (engine ffac6e0)

**Seen.** With `cutout` off a billboard, its cells were there — aimed at,
highlighted, dug, dropped — and nothing was drawn. In a scratch world on
this machine the same: the crosshair names `tall_grass`, the cell box is
drawn round nothing.

**Why.** `mesher::mesh` lights the grid's sprites and attaches them to
the mesh; `MeshJob::finish` — the incremental path `App::drive` runs for
every chunk in play — returned `scratch.finish` alone. Every sprite was
found, taken out of the geometry (§8.4) and never uploaded. The billboard
screenshot test passes because it meshes through `mesh`; it has passed
here on the RTX 5070 Ti over Vulkan, so the drawing itself is sound.

**Fix, applied in the engine tree.** `MeshJob::finish(self, light)`
attaches the sprites through the same `lit_billboards` helper `mesh`
now uses; `App::drive` passes the light it already has; a mesher test
asserts a stepped job carries the same sprites as a one-shot mesh.
Uncommitted, beside the file-mode noise already in that tree.

## 13. A billboard that is also cutout is drawn as cubes (2026-09-11)

**Seen.** Grass declared `cutout = true, billboard = true` was drawn as
cutout CUBES — cell faces showing ninths of the blade tile — with the
sprite lost inside them. In `mesher.rs` (`emit` for one axis) the opaque
set is `solid & !panes & !leaves & !sprites`, as the comment beside it
says ("taken out of every set here"), but `leaves` is the cutout column
as it came and its faces are emitted from that, sprites included.

**Fixed in the mod** by not declaring `cutout` on a billboard: the sprite
pass alpha-tests with `fragment_cutout` on its own, nothing in core reads
the flag, and the client reads it only to build the foliage set.

**Ask.** Either `let leaves = cutout & !sprites` (one line, and the
comment already promises it), or refuse the pair at registration the way
`transparent` and `cutout` are refused together — a billboard has no cube
faces for a culling rule to apply to.

## 12. Bounds of a noise node over a box (2026-09-11) — LANDED (engine ffac6e0); the mod's gate reads it through `Density:bounds` as before

**Wanted.** Two biomes share the temperate ring, split by a slow humidity
noise (period nine kilometres). A chunk is almost always wholly on one
side, but the generator cannot tell, so BOTH biomes' fills run in every
chunk of the ring — ten programs of two hundred ops instead of five, and
the probe went from no over-budget ticks to hundreds a minute in the
blended world.

**Why the mod cannot do it.** `Density:bounds(pos)` is the tool for this,
but its interval for a noise node is the node's whole range whatever the
box (the mod clamps every noise to +/-0.5 of its amplitude for exactly
that reason), so a humidity program's bounds over a chunk are always
"either side". There is no Lua-callable noise and no `Map:get`, and a
per-sample evaluation in Lua would break charter rule 4 anyway.

**Ask.** In the interval extension, bound a noise node over a box by its
value at the box's centre plus a Lipschitz term — `amplitude * K *
frequency * half_diagonal` per octave, with K the gradient bound of the
noise basis — so a slow noise over a sixteen-block chunk bounds to a sliver
rather than its whole range. Nothing else changes: `bounds` keeps its
signature, programs that never needed it keep passing, and the generator
can skip a biome whose humidity band a chunk's interval misses.

## 11. An item dropped at a position (2026-09-11)

**Wanted.** Water reaching a leaves block breaks it (`rules.lua`, on
`register_on_fluid_flow`), and the designer wants what it was to DROP. A
dig drops through the engine's own rule and a placement can be refused
with the player keeping the material, but a mod that removes a block in a
hook has no way to put its units into the world as a pickup.

**Ask.** `game.drop(position, { material = "mod:block", units = 27 })`: the
same pickup a dig makes, spawned at a position, owned by nobody.

## 10. A per-biome hue (2026-09-11) — LANDED as `game.register_chunk_tint` (engine 33dd9df); not yet used by the mod

**Wanted.** The designer wants each biome to carry its own cast: drier
biomes a little less saturated and browner, wetter ones bluer-green,
darker and richer. `tint` is per MATERIAL over one world field, so a grass
block is the same green in every biome, and per-biome block variants would
multiply the node list the designer keeps small.

**Ask.** One colour per chunk from the generator — `buf:set_tint{ r, g, b }`
(multipliers, default white) on the chunk buffer, carried in the chunk
message, and on the client interpolated between chunk centres and
multiplied into the albedo beside the material's own `tint`. A biome's hue
is then one line in its file, and the boundary between two biomes is a
smooth sixteen-block blend rather than a seam. Three bytes a chunk.

## 9. Fixed cards (2026-09-11) — LANDED as `billboard = "cross"`, engine tree, uncommitted

*Landed as the crossed form after all: the designer asked for the X of
Minecraft and Minetest by name (2026-09-11, later), two fixed cards on the
diagonals of the run's column, drawn as two instances at fixed headings
in the same sprite path. The parser now refuses a `billboard` that is not
true, false or "cross" instead of reading it as false. The hashed
single-heading form below is not needed; kept for the record.*

**Wanted.** Grass as vertical standing cards: one or two a block, each on
its own cell, each standing at its OWN angle and staying there — not
turning to face the camera. The designer's reference is a block of thin
blades fanned at all headings; from the window the present sprite reads
as a sticker that swivels as the player walks round it, and a field of
them is a wall of parallel cards. The X of two crossed quads (the first
form of this ask) is the fixed-heading look with two headings; one card
at a hashed heading is the same look with as many headings as cells, and
half the quads.

**Why the mod cannot do it.** A billboard's heading is the camera's,
built in the vertex stage from `camera_right`; nothing a mod declares
reaches that. The mod does its half already: one or two cells a block
chosen by a noise with features under a block (so neighbouring columns
decide nearly on their own), one or two cells tall and inside one block
(item 15), a tile of five one-pixel blades.

**Ask.** `billboard = "fixed"` beside the present `true`: a sprite of that
material is built from a heading HASHED from the cell's world position
(any hash — this is presentation, on the client, and no simulation reads
it) instead of the camera's right, and the same hash slides its base up
to a sixth of a block each way within its own cell's footprint, so the
cards do not stand on a three-by-three grid. Everything else as
now: one instance per run, square, the whole tile across it, both sides
drawn (the pipeline already culls nothing), lit at its foot, the top edge
swaying. The heading can travel in `world.w` and the slide in `anchor.xyz`
of the existing instance; the material's mode is one more byte on
`MaterialDef` beside `billboard`.

## 8. Sprite cards for grass, placed by the cell (2026-09-10) — LANDED as `billboard` and `sway`; grass, flowers and leaves use them

**Wanted.** Grass the way Minecraft and Minetest draw it — two crossed
alpha-tested quads — but standing on the sub-node surface rather than on
the block grid, so it never floats over a smooth slope, and with heights
that vary blade to blade.

**Why the mod cannot do it.** Every material is drawn as cells. The mod
already places grass as cells on the surface, one to three tall per
column and about half a block's columns taken; it needs the mesher to draw
those columns as cards instead of cubes.

**Ask.** `register_block{ draw = "card" }`. For every occupied cell column
of such a block — a run of the material's cells stacked in one (x, z)
cell position — the mesher emits two crossed quads, centred on that cell,
one block wide, as tall as the run (a third, two thirds or a whole
block), alpha-tested like `cutout`, unlit by face normal (both sides).
Nothing else changes: the cells still exist, collide (until item 6),
dig and drop. Nine columns a block is the most it can be asked to draw;
the mod uses four or five.

## 7. Summaries of partial blocks read as crosses (2026-09-10) — noted

**Seen.** Beyond the view distance the horizon is drawn from LOD summaries,
and a woodland's trunks — whole blocks minus their corner columns — come
out as "+" shapes floating at canopy height, with small leaf clumps as
lone crosses. Not a mod matter; recorded so it is not chased as one.

## 6. A passable block (2026-09-10) — LANDED (engine 0ab4113); ferns and tufts declare it, brambles do not

**Wanted.** Ground cover: ferns two cells tall, tufts of grass, in
carpets. A player should walk through them.

**Why the mod cannot do it.** Every block collides, whole or partial —
the contract's collision is the cell lattice, and `register_block` has no
way to say a material is not an obstacle. Knee-high fern cells are a
two-thirds lip the player steps up, so a fern carpet is a field of bumps.
The mod grows ferns in clumps with gaps for now and keeps tufts a cell
tall.

**Ask.** `register_block{ passable = true }`: the material's cells are
left out of the collision lattice (and of pathfinding's floor test) and
otherwise unchanged — drawn, lit, dug, dropped. A player walks through a
fern; a bramble stays a bramble.

## 5. Per-cell value jitter on a material (2026-09-10) — LANDED as a global one per cent (engine 9caa151), not per material; nothing for the mod to declare

**Follow-up (2026-09-10, later).** The engine agent raised it to 2.5 %
(`CELL_VARIATION` in `crates/client/src/render/world.wgsl`), and from the
window that is still too mild: the designer asks for **three times it,
0.075**. The screenshot test `one_material_is_not_one_flat_colour` bounds
the measured spread at 10 %, and 2.5 % measured as 2.6 %, so 7.5 % should
land near 7.8 % — under the bound, but the bound's comment ("catches an
order-of-magnitude mistake") wants restating alongside the constant.

**Wanted.** Every material is now a single flat colour by design (the
designer's rule: no picture ever carries variation). What breaks up a flat
surface should be the renderer's: a very slight, random VALUE offset per
sub-node cell — each cell a hair lighter or darker than its neighbour,
flat across the cell, world-anchored, the same on every machine.

**Why the mod cannot do it.** The unit is the cell, and only the mesher and
the world shader know where a cell is. `tint` is the other thing: one
smooth field per material at a scale of tens of blocks, sampled and
interpolated (`tint_noise`) — it cannot produce a flat step per cell, and
a material has one of it.

**Ask.** `register_block{ jitter = 0.04 }`: in the world shader, take the
cell of the fragment (`floor(world_position * 3)`), hash it with the
`tint_hash` that already exists, and scale the lit colour by
`1 + jitter * (hash - 0.5) * 2`. No interpolation — the whole cell gets
one value. World-anchored like the tint, under the lighting like the tint,
and `None` on the wire when a material declares none, like the tint. One
byte per material, no protocol shape change beyond the field.

## 0. A merge write: cells into a block that keeps its others (2026-09-09)

**Seen.** Surfaces are sub-node smooth, so the block a rock, a root or a
tree's root flare sits in is the block the grass cells are in. A mod can
write one material per block (`set_block` with a mask replaces the block),
so anything placed ON a smooth surface either hangs a cell above it or
turns the whole block into itself — a rock stands in a full-block footprint
of stone, a root flare makes a wood-topped block. The designer's rule is
that anything embedded in the ground embeds at sub-node resolution.

**Why the mod cannot fix it.** Two materials in one block is a mixed block,
and there is no runtime write that produces one. The engine already does
this per cell for plan stamps (`Edit::SubNode`, one per filled cell, when a
stamp layers onto a block it has replaced), so the mechanism exists; it is
not reachable from Lua.

**Ask.** `game.set_block(position, block, occupancy, { merge = true })` —
or a fourth positional — that writes `block` into the masked cells and
leaves every other cell as it was: one `Edit::SubNode` per masked cell, or
one mixed-block edit if the protocol grows one. With it a rock's cells go
into the grass block around them and nothing else changes.

## 1. Chunk serving is not paced against the tick (2026-09-09)

**Seen.** With `view_distance = 24` on a world of sub-node surfaces, every
tick logs `a tick ran over its budget — 50–80ms total: serving 44–80ms`,
with `mods` at 0.5–2 ms and `save chunks` at 4–12 ms. Serving alone is over
the whole 50 ms budget, every tick, for as long as the player moves. The
client is corrected by a late server and reads it as being pushed around.

**Why the mod cannot fix it.** Serving is the engine's; the mod does not
choose how many chunks go out a tick. A sub-node chunk is up to 27x the
cells of a block one and the serve cost (2.3 ms measured for a block chunk)
scales with it; a 24-chunk view is a 49x49x25 interest volume. The mod can
only make chunks smaller (block resolution) or the view smaller (the
player's setting), neither of which is the mod's to decide.

**Ask.** A per-tick serve budget: serve chunks in order of distance until
N ms have gone (say 15), and leave the rest for the next tick. A player
sees terrain arrive over a few ticks instead of the whole server stalling.
Second, serialising and compressing a chunk for the wire off the simulation
thread, so the tick only hands out finished bytes.

## 2. A cheap bounds probe on a density program (2026-09-08)

**Seen.** A chunk is classified from bounds the mod computes in Lua, and the
bound on the terrain field is the sum of every noise amplitude — so every
chunk within the full relief of the base dome (a band 400–2,000 blocks
thick) runs the whole surface pipeline, though the surface crosses only a
few of them.

**Ask.** `Density:bounds(pos)` — evaluate the program at a chunk's eight
corners and centre and return the min and max. Not a guarantee (noise
between samples), but with the finest octave's amplitude as a margin it
lets a mod skip nine chunks in ten. It is what the `smooth` fill already
does internally to find the crossing blocks.

## 3. Structures at generation, across chunk edges (2026-09-09) — LANDED as `game.schematic` + `buf:scatter` (engine, 2026-09-12): the alpine forest is stamped at generation

**Seen.** Trees, rocks and pools are grown at runtime by random tick,
because a generator cannot read the surface it just wrote and a structure
crosses chunk edges in every direction. Runtime growth costs a relight and
a remesh per chunk per structure and fills a woodland in over minutes.

**Ask.** A decoration pass: after a chunk and its 26 neighbours have been
generated, a second callback with a buffer that can be READ (`buf:get_block`,
or a `buf:tops()` heightmap of the highest solid block per column) and
written across the 3x3x3 neighbourhood. Deterministic from the chunk's own
stream. This is how every voxel engine with trees does it.

## 4. Maps into density fields (2026-09-08)

See `erosion-options.md`: a `{ op = "map" }` density node, `Map:fill(density)`,
and a larger or tiled map are the gate for any erosion. Unchanged.
