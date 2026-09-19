<!-- SPDX-FileCopyrightText: Iridesium -->
<!-- SPDX-License-Identifier: GPL-3.0-only -->

# Changelog

What changed, when, and why — one entry per working day, newest first.
The commit messages carry the same account; this file is the one you can
read without git. Engine changes made for the mod are listed too, with the
engine commit they landed in, because the mod is written against them.

## 2026-09-11

### Ground cover: grass as cards that stand still

- **Grass, brambles, lady's mantle and its bloom, rose bushes and their
  blooms are drawn as crossed cards** (`billboard = "cross"` in
  `blocks.lua`): two fixed cards on the diagonals of a run's column, the X
  Minecraft and Minetest draw. A card that turned to face the camera read
  as a sticker following the player. Engine: the sprite path gained a fixed
  heading per instance and emits two per crossed run; the block parser now
  refuses a `billboard` that is not `true`, `false` or `"cross"` instead of
  reading it as `false` silently. Protocol 50. Engine 79fd6e5, which also
  raises the density ceiling to 512 ops (see below).
- **Grass tufts are one or two cells tall and never cross into the block
  above** — the designer's "no stacking". They are stood on the surface by
  the engine's new cover fill (`buf:fill_cover`, `generate.lua` runs every
  biome's covers after every biome's fills), which reads the surface from
  the cells the fills wrote rather than from a field. A density field
  cannot say which block a sample is in, and the engine samples a block at
  its bottom corner, so a two-cell run confined to a block was invisible to
  the sampled fill's surface test in two thirds of columns.
- **Grass density** is about one card per three blocks (`TUFT_MIN` 0.20 in
  both temperate biomes), cut twice today at the designer's word: to a
  third of the first cut, then to 30 % of that.
- **The blade tile** is five one-pixel blades per card (`tools/make_textures.py`).
- **Two engine bugs found and fixed on the way** (engine-asks 13 and 14):
  a billboard that also declared `cutout` was drawn as cutout cubes with
  the sprite lost inside; and the incremental mesh job the game runs never
  attached sprites at all, so sprites had never been drawn in play — the
  screenshot test passed because it meshes through the one-shot path.
  `cutout` is off every billboard material now.

### Rolling Grasslands

- Sentinel trees at two thirds the size, leafier: four or five branches,
  a pad halfway and at the tip, thicker pads.
- The swells' low side deepened by 35 % (`shape.HOLLOW_DEEPEN`), so the
  hollows read more than the rises.
- **Rose bushes**: a rough ball of `rose_bush` cells on the turf with a few
  `rose_blooms` cells over its crown, planted by the grass tick in loose
  groups seven blocks apart. Two materials in one block, because every
  texture is one colour. **Picking is a dig on a bush that has blooms**:
  the dig is cancelled, every bloom on the bush turns to leaves, the player
  is given one or two `rose` items, and the blooms come back after four
  minutes or on the bush's random tick. A bare bush digs like anything else
  after a five-second grace, so a button held through the pick does not
  take the bush. A right-click pick waits on the engine (ask 16), as does
  reading the block inside the dig hook (ask 17): the world lease is not
  held there, so the hook decides on the event's material and the bush is
  read a tick later. Say `roses` in chat to be put beside the first bush of
  the session.
- The mod's tick dispatcher logs a tick error's text before the engine
  disables the mod for it; the engine says only that one happened.

### 1.3 Alpine Highlands, and programs per ring

- **The biome**: the frost ring's dry half. Fake erosion in the field
  (`shape.alpine_terms`): a staircase of hard-clamped ramps on one slow
  noise for stepped plateaus with twenty-block sheer risers; a tent along
  a noise's zero contour for thirty-block razor ridgeways; a clamped bowl
  for forty-block cirques with steep headwalls; a fine ridged noise for
  crags. Materials read the same ramps back (`shape.alpine_steep`): granite
  skin with `slate` seams, gravel drifts (the creek-bed block) down risers
  and cirque walls, `permafrost` in patches off the steep faces, thin dirt
  on the flats, and `snow` as a one-cell windswept crust by the cover fill.
  Three new materials, all named in the brief. Nothing grows by tick yet.
- **Programs per ring**: a density program cannot ask where it is, so the
  terrain and every biome's fills are compiled once per terrain mode
  (`shape.lua`, "terrain MODES") and the generator picks by the chunk's
  radius. Only the band a few hundred metres wide where the frost and
  temperate rings meet carries both rings' noise; those programs reach 382
  ops, so the engine's ceiling is 512 (was 256). Alpine chunks are the
  heaviest to generate so far: one tick over budget in forty seconds of a
  headless run, at 43 ms of generation.
- The spawn drop height gains an alpine allowance in the dev world: thirty
  blocks over the base dome sat inside the terraces, and a player put down
  in rock cannot climb out through chunks the vertical view does not reach.
- The dev switch (`tdw.config.everywhere` in `init.lua`) is on
  `alpine_highlands`.

### 1.3 Alpine Highlands, second cut: the Alps as a map

- The first cut's hard-clamped terraces on 3D noise gave overhanging
  drop-offs everywhere, because a field's noises vary in y as much as in
  x. The range is now a MAP built once per world in the pre-pass
  (`game.register_on_world_init`): a ridged multifractal (arêtes and horns)
  pulled down to flat floors along the zero contour of a slow valley noise —
  a meandering ribbon, so the valleys connect into a glacier network
  between the massifs rather than sitting as bowls (the U profile) — then
  two erosion passes over the whole map — needle peaks capped at 25 blocks
  over their 24-block neighbourhood mean, and valley floors replaced by
  their own 40-block blur so they lie flat while ridges keep their edges.
  The terrain reads it through a map node; small 3D crags stay in the field.
- `ice` is a new block (asked for by name). Above the snowline (50 blocks
  over the base dome) everything but the crests is packed snow two blocks
  deep and every valley floor and cirque is ice three blocks deep — the
  glaciers — so almost no stone shows up high; the lower slopes keep the
  scree, permafrost and thin dirt. The one-cell snow cover is gone.
- Programs that read the maps (the alpine and cross-faded terrain sets and
  the alpine biome's fills) are compiled at the first chunk that needs
  them, after the pre-pass; the rest still compile at load where the mod
  check sees them. The spawn drop height follows the range's peak.
- One map, 8 km square at 8 blocks a sample, centred on the spawn; outside
  it the map holds its edge value. Tiling the frost ring comes after the
  shape is right. A world made before this keeps generating without the
  maps (the pre-pass runs once per world), so look at it in a new world.

### Alpine lakes

- Medium to large frozen lakes on the valley floors, where a lake noise is
  high: a fourth map. The floor under a lake is smoothed with a 96-block
  blur so the lake lies level, and the fills make its top block ice and
  the eight blocks under that water. The lake is not carved: its surface
  is the floor, which keeps every lake chunk a surface chunk the generator
  paints. The water is the `water` block rather than the fluid, because
  the fluid fill takes one world level and a lake's level cannot reach
  Lua — engine ask 18 is a fluid fill by heightmap.

### Alpine, third cut: bigger, deeper snow, snow by aspect, stronger erosion

- The range two and a half times the second cut in height and breadth:
  ridge octaves from 1/3000, peaks near 0.9 km, valleys 500 blocks across,
  the map 16 km square at 16 blocks a sample. Snow four blocks deep.
- Snow lies by aspect: the snowline comes down 80 blocks in the valleys
  (the floor mask), goes up 100 blocks on the crests (the crest mask), and
  the walls — the valley mask's transition band, f(1-f) — carry none. The
  masks the map already holds stand in for the dot product with up, since
  a map has no gradient op.
- Erosion 1.75 times as strong: the peak cap's neighbourhood 48 blocks and
  the floor blur 64, and the cap 36 blocks over the mean against a range
  two and a half times taller.

### Alpine, fourth cut: detail

- Two finer ridged octaves in the range (ribs 47 and 23 blocks apart,
  weighted by the coarser as before) and ribs down the walls — the
  couloirs — from a ridged octave that shows only in the valley mask's
  transition band. Both in the map.
- Under the map's resolution the field adds a mid ridged 3D noise, ledges
  a few blocks high, three times stronger on the walls and crests than on
  the flats and quiet under the snowfields, beside the fine crags.

### Alpine, fifth cut: lower snow, mottled edges, boulders and hollows, sharper erosion

- The snowline down to 90 blocks over the base dome, and no longer a line:
  it wanders by a slow noise and is flecked by a fine one, so its edge is
  a mottled zone some fifty blocks tall.
- The material patches (slate, scree, permafrost, dirt) get two octaves
  and a fine dither at their thresholds, so they have irregular outlines
  and speckled edges instead of blobs.
- Erosion: an unsharp pass before the others — the height plus six tenths
  of its difference from a 32-block blur — which stands the arêtes and
  spurs up and cuts the gullies down, the sharper shapes from the erosion
  that were asked for; the peak cap and floor smoothing a little stronger.
- Small clamped steps in the field: a noise clamped hard, ledges about a
  block high wherever it crosses zero.
- Grown by random tick: boulders (granite, slate one in four; alone or in
  clusters) on flat snow, permafrost, dirt and scree; and hollows carved
  into granite wall faces, a chain of two to four rough spheres going in.
  Counts logged every ten seconds under "alpine:".

### Alpine, sixth cut: more rocks, lower snow, a tree line and firs

- Boulders twice as often, and small lone rocks everywhere flat besides.
- The snowline down to 65 blocks over the base dome.
- A rough tree line at 90 blocks over the dome, jittered fifteen either
  way per 24-block square, decided at runtime: a tick knows its surface
  height, and the base dome's height at that radius is a formula. Below
  it, firs grow by random tick on snow, permafrost, dirt and scree, never
  within three blocks of another's trunk: tall and thin, a cell-thin
  trunk bare for its lowest sixth and a cone of needle pads shrinking to a
  point, every block on a small tree (six to ten blocks), every other
  block on a big one (fourteen to twenty-two), so the big ones read as
  tiered. Two new blocks, `fir_log` and `fir_needles`, asked for.

### Alpine, seventh cut: bigger firs on a plus trunk, more of them, more and bigger boulders, snow patches

- Firs a quarter taller and wider, twice as dense (one surface block in
  nine below the line). The trunk is a plus of five cells in every layer,
  written as one mask per block, so it is the same all the way up — the
  thin ellipsoid it was rounded to one cell in some blocks and a plus in
  others.
- Boulders twice as often and a little bigger.
- Below the snowline, patches of snow that thin out with depth: a patch
  noise against a threshold that rises 120 blocks below the line, so the
  snow peters out instead of stopping. In the snow fill itself (a `max`
  node, new in `shape.node`), not a second program.
- Hollows start from a SURFACE tick now: it looks three blocks out each
  way with a probe that sees twelve blocks up, and where the ground stands
  five or more higher there is a wall to carve into at its foot. A tick
  on rock itself found faces almost never — the random tick picks through
  the whole loaded volume and a face is a vanishing share of the stone —
  and the rocks module's own probe scans only two blocks up, so a wall
  read as unloaded. Each growth draws its chance from its own salt of the
  hash: a rock chance of one in 45 drawn from the same number as a tree
  chance of one in 9 was never a rock. The shared edit queue lands five
  batches a second and holds twenty (from three and twelve), and each kind
  asks it for its own reserve, so a queue full of firs never starves the
  rare things.

### Alpine, eighth cut: the tick budget, dead firs, grass

- The tick budget: an alpine chunk ran nine surface fills, each
  re-evaluating the whole terrain. Now seven: the granite skin fill runs
  only where another biome shares the chunk (the generator lays the
  biome's soil under the surface already), and the lake ice is folded
  into the glacier ice fill by a `max` (the lake water written after
  takes back all but the top block). The terrain itself is cheaper: the
  fine crags are gone and the ledge detail is one octave, since an octave
  in the terrain is paid once per fill.
- Dead firs, one in twenty-one — twice the woodlands' rate: half snags
  (the plus trunk in dead wood, shorter, a broken top and a stub or two),
  half fallen trunks lying along x or z, merged into the surface.
- Grass: sparse tufts of `alpine_grass` stood by the cover fill below the
  snowline where the ground faces up, off the crests and lakes — the
  temperate blades in a darker, desaturated blue-green with its own cold
  tint, shorter, wind-flattened.

### Alpine, ninth cut: a third the grass, three times the trees, boulders twice the size, dirt and turf, bigger lakes

- Grass a third as common; firs one surface block in three below the
  line (a forest, held apart by the spacing); boulders twice the size;
  lakes larger and more of them.
- Granite about a third as common on the surface: dirt three blocks deep
  over most ground below the snowline that faces up, and turf (the
  `grass` block) over most of that below the tree line, so the granite
  shows on the walls, the crests, and the patches these leave. The
  surface tick grows on turf too.
- Engine: the client stops drawing sprites (grass, bushes) beyond seven
  chunks and cutout foliage (leaves, needles) beyond eleven, measured to
  the chunk's centre. This is the frame's cost, not the server's tick.
- The tick: a single alpine chunk took over fifty milliseconds to
  generate. The world's own two detail octaves are left out of the alpine
  terrain (the map and the ledges carry that scale), a third of the noise
  in every alpine fill; tree tries check the block above first and size
  their loaded box to the tree, and are one in five rather than three.
  The remaining cost is structural — every fill re-evaluates the terrain
  — and is engine ask 19, a palette fill: one evaluation, many materials.

### Alpine, tenth cut: more and bigger boulders, cold turf

- Boulders twice as often again and three tenths bigger.
- The turf is `alpine_turf`, a new block in the same cold blue-green tint
  as the alpine grass that stands on it; the shared `grass` block carries
  the temperate tint and a tint is per material.

### Alpine, eleventh cut: crevasses, more needles

- Crevasses, now and then, on the glaciers and the high snow: a crack
  fourteen to thirty-four blocks long along x or z, eight to twenty-two
  deep in the middle and shallowing to its ends, one to three wide, its
  walls coated with ice — one tall ellipsoid of ice written first and a
  slightly smaller one carved out of it as air, merged so the ground
  round it stays. Grown by the surface tick on ice and high snow; say
  `crevasse` in chat and one is carved where you stand, to look at.
- Firs carry a quarter more needles: pads an eighth wider and thicker.

### Alpine, twelfth cut: one fill for the whole surface; the tree line up

- The alpine surface — slate, scree, permafrost, dirt, turf, snow, the
  glaciers and the lakes — is ONE fill: `buf:fill_layers`, new in the
  engine beside its palette fill. The terrain is evaluated once, smooth at
  the cells; a code field evaluated once at block resolution names which
  set of depth bands each block gets (the greatest of k times a stepped
  condition, later layers larger); a table maps code and band to
  material. The engine's palette is a single value against thresholds,
  right for depth bands and wrong for a category, which the smooth detail
  would interpolate at every patch edge and at the surface itself. Eight
  evaluations of the terrain a chunk are one.
- The tree line up to 200 blocks over the base dome, jittered forty
  either way, and tries one surface block in two: at 90 most of the range
  stood above the line, and growth by tick took minutes to fill a chunk.

### Alpine, thirteenth cut: snow as a deposit, the forest fills in, cold ice, boulders halved

- The snowfields are a deposit: where snow lies above the line the
  terrain itself stands four blocks higher (`snow_lift`, a term of the
  alpine terrain, tapered in over four blocks of height above the
  wandering, flecked line, and off the lakes, walls and crests over their
  masks), and the snow layer there is eight blocks deep — double — so it
  is those four blocks and four under them, and a snowfield's edge is a
  bank, mottled by the fleck. The glaciers stand up with it; their ice is
  six deep so it reaches under the lift. The patches below the line stay
  flat and four deep: a mound at every patch would be a field of lumps,
  and the patch noise in every terrain evaluation cost a fifth of a
  chunk. The patches' fade reads the line from the maps alone, three
  octaves fewer. The snow's masks moved to file level, written
  left-leaning, because the lift is evaluated inside the terrain with
  buffers already held. Chunk generation with the lift: about five
  milliseconds a chunk, from four.
- The forest fills in. Two ceilings on it, both raised. The edit queue
  landed five batches a second across every loaded chunk (a thousand
  three hundred fir tries in ten seconds, thirty-seven landed, seven
  hundred refused for room): it lands a batch every tick now and two a
  tick when it is filling, twenty to forty a second (four a tick built
  firs faster than the tick could relight them). And a
  random tick on buried snow — seven in eight of them, now the snow is
  eight deep — was a try refused for headroom: a buried tick is taken up
  to the surface of its column, so the whole depth of the snow ticks its
  surface. And a block of two materials names none (`material` nil,
  `cells` listed) — which is the surface block of most columns, the
  grass cover standing its cells in the top block's air — so every read
  of a surface material is now by cell (`holds`, `is_surface_block`), and
  the grass cover is open to a trunk, as in the woodlands. The firs stood
  in patches where the player had waited and nowhere else; growth by tick
  is still growth by tick, and a chunk's forest is there within a minute
  of its loading rather than at generation (engine-asks 3).
- Ice is cold blue: a blue texture and a blue-shifting tint.
- Boulders halved: they stood twice the size they read on paper.

### Alpine, fourteenth cut: the forest at generation, ice crusts lower down

- The forest is generated, not grown: the firs (twelve small, six big,
  a snag) are built once at load as schematics from the same shape code
  the tick uses — pushed blind through the edit queue and taken as a
  list — and the engine's new `buf:scatter` stamps them at generation:
  one candidate a square of three blocks, half the squares, on the
  surface it finds down each candidate's column, where the `stand`
  field allows (below the tree line as it wanders, off the lakes, walls
  and crests), across chunk edges by the neighbourhood rule. A fir per
  eighteen columns, fourteen a chunk, the moment the chunk exists. The
  tree line is up to 320 blocks over the dome (200 was the valley
  floors and little else): "groups of trees six to ten times too rare".
  The random tick still grows firs, held apart from these, so the
  forest thickens where it stands. On an engine without
  `game.schematic` the mod logs it and the tick alone grows the forest,
  as before.
- Ice crusts lower down: a crevasse can crack any alpine surface now,
  and below the line its coat is a crust — thinner (0.4 past the crack)
  and rough enough to be patchy; the glaciers and the high snow keep the
  full coat. The carved hollows get the same crust round every sphere,
  written before the carves so a later sphere's crust does not fill an
  earlier one back in.
- (Engine, same day: leaves inside a canopy are meshed opaque, and
  foliage beyond the cutout draw distance is drawn solid instead of
  dropped — see the engine's contract §8.2. Nothing to do in the mod;
  the leaf textures already carry the leaf colour under their holes.)

### Alpine, fifteenth cut: fewer firs in stands, the spawn on the ground, whole trees across chunks

- Firs thinned to seven tenths (a square in 0.35 rather than half) and
  the forest confined to stands: a coarse noise gate on where a fir may
  stand leaves about three fifths of the ground below the line forested,
  in stands a few hundred blocks across with open ground between. "Thin
  the trees to 70% and the forested areas to 60%."
- A new player no longer falls a thousand blocks: the spawn's ground is
  found from the terrain field itself (`shape.ground_at_column`, some
  two hundred samples of the column, once) the first tick the seed is
  known, and the player is put six blocks over it before the block reads
  confirm the landing. The fall is a few blocks.
- The tick-grown firs try one surface block in nine rather than three:
  a thickener now the forest is stamped at generation, where a third of
  all surface ticks were fir tries refused under it.
- Trees cut off by chunks (engine): the scatter judged a candidate's
  surface over a window that differed per chunk, so a ledge under an
  overhang got a tree from the chunk below and no crown from the chunk
  above. A surface is now a crossing with no other crossing within the
  structure's height above it, judged over the same column from every
  chunk; nothing stands under an overhang, and the higher surface gets
  the tree whole from every chunk it reaches. Tested across three
  stacked chunks and under a slab.

### Alpine, sixteenth cut: no blobs in the trees, no walls of ice, nothing on ice, roots

- "Blobs floating in the trees": the hollow carver's ground probe took a
  fir's crown for a wall (three blocks out, five blocks up: a wall by its
  rule) and carved a hollow into the tree, ice crust and all. The probe
  now reads through trunks, needles, dead wood and the grass cover.
- "Whole messy walls of ice": the crevasse's coat and the hollows' crust
  were written over their whole ellipsoid, air included, so on a slope
  the coat stood out of the hillside as a slab. Both are written into the
  rock that is there and never into air (the `carve` mask with the ice as
  the material).
- Nothing grows on ice: the surface tick on an ice block takes only the
  crevasse, and the scatter's `stand` field keeps off the glaciers (the
  floors above the snowline) as it already kept off the lakes.
- Roots, in every biome: a block of trunk under the base — the fir
  schematics and the tick-grown firs and snags, the woodlands' trees and
  snags, the grasslands' sentinels — so a trunk continues into the
  ground rather than resting on it.

### Alpine, seventeenth cut: cracks in the terrain, a cheaper cover

- The crevasses are cracks in the terrain field now, not carved after by
  the tick — which cut them through the stamped forest, and made them
  small and jagged besides (a roughed-up ellipsoid, where a crack is a
  smooth wedge). A crack term of the alpine terrain: along the zero
  contour of a slow 2D noise, within a block and six tenths of it at the
  mouth narrowing to nothing eighteen blocks below the map's surface, a
  wedge with crisp smooth vertical walls, curving along the contour; in
  lengths of some sixty blocks tapering to their ends (a segment noise),
  over about a third of the ground (an area noise), off the lakes. A
  tenth layer code lays an ice rim a block and a half into the walls and
  round the lip. The firs' `stand` keeps two blocks clear of the cracks.
  `carve_crevasse` stays for the chat word. The width is the engine's new
  `contour` node — the distance to the line, so it is the width
  everywhere along it; the first cut used a band `|noise| < w`, which is a
  line only where the noise climbs and a pond where it lies flat, and it
  covered a fifth of the ground and took three firs in four with it.
- Optimization: the alpine cover's `take` carried the whole terrain,
  negated, as a "near-surface guard" — positive in all air, so it guarded
  nothing — and the cover fill evaluates its field over the 27 cells of
  every surface block: ten octaves, seven thousand times a chunk. It is
  the map depth now, no noise, and keeps the cover off a cave's floor,
  which is all that was wanted.

### Alpine dials, and 1.4 Coastal Cliffs

- Alpine: the cracks over a twentieth of the ground rather than a third
  (the area gate's threshold to the noise's ninety-fifth percentile), the
  hollows one surface tick in eight hundred rather than one in a hundred
  and twenty — "15% as common" — and the firs at 0.28 of the squares,
  four fifths of before.
- 1.4 Coastal Cliffs (`biomes/coastal_cliffs.lua`, terrain mode
  `coast`). The world's surface is a dome and a sea is flat, so the
  biome's terms cancel the dome and stand the land on one sea level eight
  blocks under the spawn base, and the generator fills the engine's water
  fluid below it in every coast chunk — a chunk of air over the seabed
  included. Land is where a three-octave kilometre noise is positive; the
  cliff is the `contour` distance to that coastline, the plateau's height
  (thirty to sixty blocks, by a slow noise, with a couple of blocks of
  relief) rising over two blocks — sheer — or over twenty-eight where a
  beach noise says. Sea stacks: a fast noise over a threshold on the sea
  side within reach of the shore, at the plateau's height. The seabed
  twelve blocks down. Cut from the land: an undercut notch three and a
  half blocks into the face within two and a half of the sea level; sea
  caves where a fast 3D noise is high within seven blocks of the line and
  two to sixteen over the sea, which through a thin headland are arches;
  and the alpine's cracks, a block wide and twelve deep from the cliff
  top in stretches, opening the face as fissures. Materials by the
  layered fill: eighteen horizontal strata of stone, dark basalt, slate
  and limestone (standing in for sandstone) from twenty blocks under the
  sea up; the splash zone within three blocks of the sea and six of the
  line — dead coral where a fast noise is high, gravel where it is low;
  gravel over the beaches; a block and a half of turf on the plateau with
  sparse tufts by the cover fill. Two new blocks, `dark_basalt` and
  `dead_coral`. The dev switch is on it. Open: where the sea sits in the
  ring world, whose Long Shore drops eight hundred metres across its
  width — one level, a shelf, or terraces is a design call.

### Optimization: the body by the layered fill — one terrain evaluation a chunk

- The spawn's aim has stood down: the engine generates terrain in worker
  VMs now, so the seed the generator recorded never reaches the main VM,
  and nothing on the main thread carries it (the chunk tint is asked in
  the workers too). A new player falls the old way again — hopping down
  a hundred and sixty blocks a tick through loaded chunks — until the
  engine sets `game.world_seed` in every VM (engine-asks 21), which the
  aim reads as soon as it exists.

- The generator evaluated a chunk's terrain three times: its own body
  fill, its stone-below-the-soil fill, and the biome's layered fill's
  depth. The engine's layered fill takes a wildcard layer now (code -1,
  `to = math.huge`), so a biome whose surface is a layered fill lays its
  body too — the soil to SKIN_DIRT and the stone below it, after the
  coded bands — and the generator runs neither of its own fills for a
  chunk wholly in such a biome (`body = true` on the fill; a chunk two
  biomes share keeps the old path). The alpine and the coast both. The
  coast's first cut generated at forty-eight milliseconds a chunk.
- The coast, cheaper besides: the island under the spawn without its
  wobble (a contour in every read of the shore); the shelf's shapes from
  the coast's three-octave line, read only at sea; the cuts in two groups
  sharing one read of the shore each; the tufts' field without the
  land's height, which the cover fill evaluates over every surface
  block's twenty-seven cells.

### Coast, second cut, and the Coastal Shelf

- The coastline has a fourth octave (137 m). The face is jagged over most
  of its length: a fast 3D noise of two and a half blocks either way
  added to the terrain within six blocks of the line, above the splash
  zone, where an area noise says (most areas). The cliff-top cracks are
  a tenth of the contour length rather than two fifths ("reduce by
  75%").
- Pines along the rim: ten templates of a trunk three to five tall bent
  over a block or two near the top, a root under, and three to five
  clumps of needles about the top with half their cells each — small,
  wind-bent, sparse and chaotic — scattered one square in six blocks at
  0.35, between three and twenty-six blocks in from the coastline (never
  on the face, whose two blocks the band starts past), in stands where a
  patch noise says and always within three blocks of a crack line
  ("trees cling to fractures").
- The turf and its tufts are light yellow-green: two blocks, `coast_turf`
  and `coast_grass`, since a tint is per material and the chunk tint
  would carry the strata with it.
- Flooded caves and blowholes: tunnels five wide and seven tall along the
  contour lines of a slow noise, from four blocks under the sea to three
  over, seventy blocks inland, where an area noise says — flooded, since
  the sea fill takes every air cell under its level; and where a tunnel
  line crosses a second noise's contour, a shaft a block and a half
  across from the tunnel floor up through the plateau, within forty-five
  blocks of the shore. Sea spray erupting from a blowhole is particles,
  and an engine ask.
- The Coastal Shelf, the same biome's sea side ("lift the biome lock so it
  is all one biome"): the seabed is a terrace from two to twelve blocks
  under the sea over the first eighty blocks out, a drop-off ledge of
  thirty more over fourteen blocks at a hundred out, two sandbars two
  and a half blocks high parallel to the coast at twenty-eight and
  fifty-eight out with the gutters between, rock flats level at four
  blocks where a slow noise says, and hollows seven deep for the kelp.
  All of it from the coast noise's unsigned contour distance, one buffer.
  Materials by five more layer codes: sand four deep this side of the
  ledge's foot, gravel beds in it, the flats' limestone pavement, and on
  that ocean moss and barnacles by two fast noises. Life by the scatter,
  on the seabed the field finds, before the sea is filled: seagrass
  columns two to four tall one square in two at 0.65 in prairies over
  the terrace off the flats, kelp columns eight to twelve tall one
  square in four at 0.35 eight blocks down or more, boulder clusters
  (three by three, two tall, by chance, barnacles on the tops) on the
  flats, crab burrows (a hole a block down, a ring of sand half a block
  high round it) on the sand. A card block holds three of its
  twenty-seven cells, so the sea fill puts twenty-four cells of water in
  it and the plant sways in the sea. Five blocks: `sand` (the floor, and
  nothing stood in for it), `ocean_moss`, `barnacles`, `seagrass`,
  `kelp`. Barnacles are a crust on rock, so a block laid by the layered
  fill and stamped on the boulders, not a card.

### Coast, third cut: a calmer line with real detail, a jagged face, a smooth floor

- The coastline is two octaves again (a kilometre and 550 m: the broad
  sweep), and its detail is added to the DISTANCE rather than to the
  noise. A coast noise with fine octaves has a steep gradient everywhere,
  and the contour node divides by that gradient, so four octaves made the
  line meander without ever getting small. Added to the signed distance
  the line moves in and out by so many blocks at the scale asked for:
  bites of a dozen blocks at a hundred and fifty metres, then
  crenellations of two at nine, and the cliff edge follows every one.
- The face is jagged over four fifths of the coast rather than most of
  it, by four and a half blocks either way rather than two and a half,
  at eleven metres and five and a half rather than seven, nine blocks in
  from the line rather than six.
- The sea floor was a set of holes with drop-offs round them: the flats
  and the hollows were hard clamps, switching the bed between levels
  over a block. Both come in softly now (a tenth as steep, so a flat's
  edge is tens of blocks), the hollows are five blocks deep rather than
  seven, the sandbars slope over nine blocks rather than five, and a
  long swell of two and a half blocks at a hundred and ten metres runs
  through the whole floor.
- The pines are bigger and leafier — five to eight blocks of trunk, six
  to nine clumps of needles at three cells in five rather than two —
  and rarer: a square in seven at 0.22, where it was a square in six at
  0.35.
- The spawn headland is fifty-five blocks across rather than ninety: at
  ninety the sea began past the view distance, and the dev world is here
  to look at the sea.

### Coast, fourth cut: the jag runs down the face, and the sea floor has no slabs

- "The cliffside needs to be jagged on a primarily vertical axis; right
  now it's jagged on every axis." A term that varies with x and z but not
  with y moves a vertical face in and out by the same amount at every
  height — a rib the height of the cliff — where a 3D noise moves it by a
  different amount at every height, which is a lumpy face. The engine's
  noise node is 3D, and the one field of the ground plane alone the
  language has is `contour`, so the ribs are its lines: rock out along
  each, recessed between, at thirteen blocks and five, four and a half
  blocks and a block and a half of throw. The only part that still varies
  with height is three quarters of a block of grain, so a rib is not a
  cast column. Cheaper than what it replaces, too: a contour is five
  fills of the ground plane where a 3D octave is a fill of the volume.
- "Under the water there are some completely flat noise shapes." The rock
  flats set the floor TO a depth, so each was a dead-level slab in the
  shape of the noise that chose it. A flat pulls the floor a little over
  half the way to a level that is itself rippled by most of a block, so
  it is flatter than the floor round it — wave-scoured, which is the
  design — and never a slab. The pavement, the moss and the barnacles
  still follow the same noise, so the flats are still there to find.

### Coast: half the throw on the face, and the grain twice as tall

- "Dial back the noise on the cliff face to about 50% and stretch it out
  on the vertical axis about 2 times." The ribs and the fluting are half
  what they were — two and a quarter blocks and three quarters — and the
  grain, which is the only part of the jag that varies with height (the
  ribs run the cliff's whole height already), is half as strong and half
  the frequency: twice as tall, and twice as wide, which the fine rib at
  five blocks covers. A per-axis noise scale would stretch it in y alone
  and is written down as engine-asks 22.

### The world, not one biome: every built biome placed by temperature

- The dev switch is off. `tdw.config.everywhere = nil`, and the world is
  the rings again.
- Four biomes are built against eight rings, so each holds every ring its
  temperature suits, which is what "score them by how cold or warm they
  are" comes to: the alpine has the cold core (the Crown and Frostmoor,
  both humidity halves); the grassland has the dry half of everything
  outside it AND the whole width of the two hot rings, the Ember Ridge and
  the Glass Waste, which is the dry band round the middle of the world
  until there is a desert; the woodland has the wet half of the mild rings
  either side of that. A biome's `spans` in the catalogue say which rings
  and which humidity half of each, and its mask is their union.
- No edge is a circle. The radius the BIOMES are placed by is the true
  radius pushed in and out by a slow noise — `shape.RING_WOBBLE`, ten
  thousandths of u at five kilometres, which near the frost edge is about
  two kilometres of wander either way — while the world's own shape keeps
  the true radius, so nothing about its form depends on it. Every Lua-side
  ring test widens by the wobble, and the alpine's blend band widened with
  it (0.003 to 0.024 of u) so the cross-faded programs cover every place
  the edge can be. The wet/dry line was never a ring: it is the humidity
  noise.
- The alpine's map moved. Its terrain IS a map, so the biome reaches
  exactly as far as the map does, and the map was centred on the spawn —
  fifteen kilometres out, nowhere near the cold core. It is centred on the
  axis now and 24.6 km across (1024 samples at 24 blocks, from 16), a hair
  over the twelve kilometres the core can reach once the wobble has pushed
  it. The blurs are in fewer samples to keep them the same distance in
  blocks: sharpen 2 to 1, peak 4 to 3, floor 5 to 3, lake 14 to 9. The dev
  switch still centres it on the spawn.
- A biome is found where one of its SPANS is, not over the whole range its
  spans cover: the grassland alone holds the two hot rings, and the
  woodland would otherwise have been found there, run its fills, painted
  nothing, and cost those chunks their one-evaluation body.
- A warmth field that moved the wet/dry split with the radius was tried
  and taken out: it sits inside `dry_weight`, which the temperate terrain
  evaluates while it holds the wet terms, and that came to ten live
  buffers against the engine's eight. Which ring a biome is warm enough
  for is a fact about the biome, and it lives in its spans.
- Small kelp groves on the shelf, as the design says: a sixth of the deep
  floor rather than half.

### What no biome claims is white

- Four surface biomes are built and every other area in the catalogue has
  a registered biome and no code behind it: the three cave bands, the five
  shells of the core stack, the tail below the apex. All of it was filled
  with the layer table's stand-in rock — stone, gloam stone, abyss stone,
  magma crust, marrow, apex stone — which looks like rock and reads as
  finished work.
- It is the core mod's white placeholder block now, everywhere below the
  surface band: the one depth band whose area has biomes is the top
  hundred blocks, and the normal caves begin under it. A chunk wholly
  below the line takes white as the material it is filled from; one
  straddling the line takes a fill of its own (`top.deep`, the depth
  against the band's bottom, which the flank set carries too). The shells
  and the tail take it wherever they are.
- `tdw.config.white_unbuilt = false` puts every stand-in back. The line
  itself is `shape.SURFACE_BAND_D`, which layers.lua asserts against the
  surface band's own bottom so the two cannot drift.

### The biome you are in, on the HUD and from chat — and the blend band that could not generate

- **A chunk in the band where the frost ring meets the temperate one could
  not be generated at all.** The cross-faded program that carries both
  rings' terms needed nine of the engine's eight buffers, so every chunk
  there failed and the failure disabled the whole mod. It had never been
  compiled before: the dev switch pinned every world to one ring, and one
  ring's terms fit. The fix is the order the terms are added in — the
  stack machine holds every pending operand, so `add(a, b)` peaks at the
  deeper of `peak(a)` and `1 + peak(b)`, and the ring's own terms belong
  first, the world's hills after, the depth last. The same reordering the
  coast needed when it was written. `top.all.solid` is 378 ops and eight
  buffers now.
- The biome you walk into names itself on the HUD for a second, small and
  centred at the top. The server reads the ground under each player every
  half second and speaks only on a change; unloaded ground says nothing
  rather than blanking the name. Which biome a place belongs to is a field
  of the radius and the humidity noise, and the seed those need is not in
  this VM (engine-asks 21), so the ground is read instead — every biome
  lays its own materials, and the alpine's win over the rest because it
  lays thin dirt in its hollows and dirt is the grassland's own soil.
- Saying `alpine`, `woodlands`, `grasslands` or `coast` in chat sends you
  looking for that biome. The humidity half cannot be evaluated here
  either, so the search is by trial: dropped on one azimuth of the
  biome's ring, landed, the ground read, and round to the next azimuth if
  it is the wrong one, up to sixteen. `tdw.config.spawn_biome` runs the
  same search for a new player instead of the fixed spawn.

### 1.6 River Valleys, and the dome that cost two buffers everywhere

- Troughs cut across every ring from the temperate one outward, with a
  river down the middle. The course is the zero contour of a slow noise
  read as a distance in blocks, and everything reads that one distance:
  the channel nine blocks either side of it, the gravel bank and the point
  bars to seventeen, the alluvial terrace to fifty-eight, the valley rim
  at a hundred and fifty and twenty-six blocks above the water. A slow
  noise along the course decides which bank is the undercut bluff and
  which the wide point bar, by stretching the bank on one side and
  squeezing it on the other.
- The valley is SUBTRACTED from the terrain rather than being a mode of
  its own (`shape.river_valley`, called from `M.terrain`): the trough's
  surface is the world's smooth height minus the profile, and the terrain
  is the lesser of itself and that. So a river crosses biomes and the
  uplands keep their shape; past the rim the profile rises a kilometre so
  the trough never bites. It is kept out of the mountains by the alpine
  weight, and off the coast, which has a sea of its own.
- The water is the water BLOCK, as the alpine lakes are. A fluid has to be
  flat and a river that runs across a 2.5 km dome cannot be; a block takes
  whatever height the valley floor has, and because a block's height is an
  integer the surface comes out as a staircase of one-block steps — which,
  with the riffles laid on them, is what a river does. Pools are five
  blocks deep over sand, riffles one over gravel, by a noise along the
  course.
- Materials by the layered fill: moist sand for the bed and the wet bank,
  clay (mud) along the water line, gravel on the banks and bars, bedrock
  shelves scoured bare where the flow is fast, turf over soil on the
  terraces and slopes, and spring seeps weeping from the valley walls.
  Cover: dense water iris in the shallows, wild mint on the damp ground
  behind it, grass over the terraces.
- Trees and accents by the scatter: eight willows — four stems on a
  two-by-two footprint, each twisting its own way, the whole leaning, a
  broad crown and eight to twelve curtains of leaves hung from its rim
  and longest on the side it leans over — hugging the shoreline; five
  palms standing back on the terraces; snags and drift jams of two to
  four crossed trunks lodged on the bars; stepping stones in the
  shallows.
- Five blocks, all asked for by name: `willow_wood`, `willow_leaves`,
  `willow_planks`, `water_iris`, `wild_mint`.
- A river is a LINE, so the biome answers `present(pos)` with one sample
  of its own course at the chunk's centre; a chunk no course reaches never
  evaluates its terrain or its code field. `tdw.present_biomes_in` is what
  the generator asks now.
- **The dome was built constant-first and cost two of the engine's eight
  buffers in every program in the world.** The radius is three buffers of
  its own, and it was evaluated with two already held. Written
  radius-first the dome peaks at four instead of six — which is what
  stopped the river's code field compiling, and is a saving everywhere.
  The relief mask and the plain mask had the same fault and are fixed with
  it. Every mode's programs are built on demand now, too: the temperate
  set used to be built at load, which was before the river had defined the
  trough it cuts into them.
- Saying `river` in chat looks for one, and the ground identifies it by
  its willows and its iris.

### A roof of turf over every river valley

- Every biome's fills carry the terrain INSIDE them — a grass band is the
  shape of the ground, three blocks deep — and a fill writes its material
  wherever its field is positive, whether or not there is ground under it.
  The woodland and the grassland built their fills at LOAD, which is before
  the river valleys file had defined the trough it cuts into the terrain,
  so their bands were the shape of the ground before the rivers were taken
  out of it: a slab of soil and turf hanging over each valley, with trees
  growing on it.
- Both are built on demand now, like the alpine, the coast and the river.
  The flag has to be set BEFORE `build_biome`, which reads it when it runs;
  set after, as it was first tried, it changed nothing at all. The
  grassland's grass field went from 228 operations to 373, and the 145 are
  the valley cut that was missing from it.
- `sand` is nobody's marker for the "which biome am I in" lookup any more:
  the shelf's floor is sand and so is a river's, so it named every river
  bed the coast.

### A trunk is a path with a thickness

- "Would it be possible to generate them by first drawing a path and then
  choosing a thickness and filling along that path?" Yes, and it is what
  `schem.push_path` does now: a list of points, each with a radius, and
  every cell within that radius of the line through them becomes the
  material, the radius carried smoothly from one point to the next. A
  trunk tapers because its last point is thinner than its first; a branch
  leaves at whatever angle its points do; a frond droops because its
  points droop. The distance from a cell to a segment and nothing else,
  squared throughout so there is no root to take, in the same plain
  arithmetic the ellipsoids use.
- The river's trees are built from it. A palm is one bowing stem and seven
  to nine fronds, each arcing up and out and drooping at the tip, where it
  was a stack of blocks with three-block arms stuck on top — which is what
  made it look like a signpost. A willow is four twisting stems, branches
  arcing out of their tops with a clump of leaves on each, and curtains
  hung from them, longer on the side the tree leans over. A snag is a
  trunk lying on a bar, which is a line with a thickness too. Five
  willows, four palms and five snags come to 3,156 blocks of schematic.
- Two things the rasteriser needed. Most blocks in a segment's box are
  nowhere near the segment — a trunk is slender and its box is not — so
  the block's own centre is tested first and rejects them for ten
  operations rather than twenty-seven cell tests. And the trees are built
  at the first valley rather than at load: cutting them out of cells is
  tens of thousands of operations, and the registration window's
  instruction budget is a good deal smaller than a generator call's.
- Looking for a river now walks outward on one heading rather than turning
  round the ring. A river is a line: courses are two and a half kilometres
  apart, so a few steps of four hundred metres crosses one, where turning
  round the same ring lands between them more often than not.

### A chat word answers instead of being refused

- Typing a biome's name gave back "a mod refused that message". The engine
  takes `false` from a chat hook to mean the line is going nowhere and
  tells the speaker so, which reads as an error when it was a command being
  obeyed. A STRING stops the line the same way and shows the speaker that
  string instead, so every word this mod registers returns one: `river`
  says it is walking outward until one turns up, `roses` gives the bush's
  position or says none has grown, `crevasse` says whether it cracked the
  ground under you, `stats` says the figures are in the log, and `where`
  answers with the biome you are in and the Spindle's own coordinates.
- A word that errors is caught and says so rather than taking the tick
  handler down with it.

### River water that is water, a channel it sits down in, and path-built oaks and pines

- **The river's water is the engine's water fluid** — "water there does not
  seem to be registered as a fluid, it is just a block". It was the water
  BLOCK painted into the top of the channel's ground: it looked like water
  and it was a floor. The fluid could not simply be laid at the river's
  level, because that level falls as the river runs down the dome — about
  one block in twenty on the steepest rings — and a conserved fluid on a
  slope runs to the bottom of its valley the moment its chunk loads (every
  generated block of fluid is woken on load). So the engine gained
  `buf:fill_fluid_terraced{ level, within, fluid, lip }` (engine 81ba792):
  the level is a density read once per column and taken down to a
  whole block, every block below it is filled around the terrain as a sea
  is, and wherever a neighbouring column stands a block higher this column
  gets a LIP of `lip` material up to it. The river comes out as level pools
  held up by one-block stone steps — the riffles — and nothing in it can
  move: every block of fluid has fluid or a whole block beside it at its own
  height and under it, whatever path you take. An engine test asserts
  exactly that. Headless, 2,288 blocks of river beside the spawn held a
  volume of 57,918 cells at one reading and 57,918 thirty seconds later.
- **The channel is carved under the water's level**: a smooth U, 2.5 blocks
  deep at the middle and 4.5 in the pools (which fade in over a few blocks
  instead of being five-block holes with walls), rounded humps up to 1.2
  blocks high in the bed here and there, and a three-block bank up out of
  the water to 2.2 blocks over the level. A column's water fills whole
  blocks up to the block its level is in, so the surface stands at least
  1.2 blocks under the bank top: "the water can sit down in the creek at
  least a block". The drop-off and the full-height sand banks were the
  painted water: a staircase of water blocks laid on flat ground, with the
  pools painted five blocks down into it.
- **No grass across the river.** The woodland's and the grassland's tufts
  (and the woodland's ferns) stood on whatever surface the river left,
  including its water blocks, which is what the strips were; with the water
  a fluid they would have stood on the bed under it. `shape.river_exclude`
  keeps them out: the tufts from the whole valley (150 blocks either side
  of the course), the ferns from the channel and the banks (17).
- **70% the grass.** The valley carried the river's own grass (a card on
  32.5% of cell columns at `GRASS_MIN` 0.22, measured over 20,000 samples)
  and its host biome's on top — 44% of columns where woodland hosted it,
  55% where grassland did. With the hosts' kept out, the river's own at
  0.20 is 34%: 77% and 61% of those, 70% between them.
- **70% fewer drift piles, lying in the ground.** `SNAG_SQUARES` 0.35 to
  0.105. Each pile is one to three short trunks (two to four blocks, was
  three to seven); the first runs a tenth of a block over the surface
  block's floor, so its lower half is in the ground, any others lie across
  it a third of a block higher, and each dips half a block to its far end
  so it digs into a slope rather than sticking out over it. They lie on the dry bank and the bars, never in the
  channel or on the steep bank out of it, and the scatter sinks their root
  into the surface block (`sink` 1, was 0: they stood on top of it).
- Stepping stones are columns of three or four blocks from the bed of a
  riffle up through the water, since a one-block stone would be under it
  now. Seeps on the valley walls are wet mud; they painted water blocks
  too.
- **The woodland's oaks and aspens are paths with a thickness**, as the
  river's trees are — "I want regular oak trees to be switched over to that
  technique". The trunk tapers from a flared foot (radius 0.84, 0.7 at the
  grass, 0.42 at the top), leans its own way and wanders a little as it
  climbs; branches leave it at their own heights and angles, rise as they go
  out and carry a ragged clump at the end, and one oak branch in two has a
  twig off its middle with a smaller clump, so the canopy is lumps and
  gaps; root flares run down and out into the turf; a fork in one oak in
  four has a crown of its own. Aspens are the same code with a slender
  trunk and short branches up a tall one. They still grow by random tick
  and are read against the world as the blocky ones were — trunk always,
  other wood into open air, leaves where the column is clear — but each is
  a TEMPLATE cut once (twelve oaks, six aspens, one cut a tick at most) and
  stamped, so a grown tree costs its reads and nothing to cut. Wood takes
  its cells before leaves in every block (`schem.merged`); a clump over a
  branch tip used to take the branch's cells.
- **A bug found testing it, before it shipped**: a runtime edit takes a
  block's NAME, and a template holds ids, so the first headless run "grew"
  160 oaks in ten seconds and wrote none. The templates carry names.
- **The coast's pines are paths** too: a trunk that climbs from a flared
  foot and bows over downwind for its top three blocks, four to six flat
  pads of needles swept the same way off short limbs up its upper part, and
  a broader pad on the tip. They are cut at the first coast chunk rather
  than at load, like the river's trees. The coast is still not placed; seen
  with `everywhere = "coastal_cliffs"`, headless.
- `schem.lua` gained `path_point` (the point on a path at a height, for a
  branch off a trunk), `capture`, `merged`, `schematic_of` and
  `schematic_of_batch`; the river's own copy of the last is gone.
- Verified headless: the engine's unit tests (the two new ones included)
  and clippy; the mod check; a river at a fixed seed with the spawn moved
  onto it; the woodland and the coast each put everywhere; and the real
  world with a three-bot swarm for ninety seconds, with no over-budget tick,
  no refused program and no error. The engine's two reference-generator
  golden tests fail on this machine because `game/` holds the junction to
  this mod, which replaces the reference world they check.

### A straight river, and 1.7 Dense Rainforest Canopy

- **The river's stone lips are gone** — "get rid of those stone pools and
  just make it a straight river. I will fix the water physics so it doesn't
  all flow away." The fluid fill takes no `lip`, so the river is one body of
  water down its whole course, each column filled to its own level; keeping
  it there is the engine's, which the designer is doing.
- **1.7 Dense Rainforest Canopy**, the wet half of the Verdant Belt, which
  the woodland gives up (it keeps the temperate ring, the Long Shore and the
  Hem). `biomes/dense_rainforest_canopy.lua`.
- **The ground** is terms of the terrain added to the wet half's own by a
  verdant weight, in a new terrain mode, "verdant", for the belt and a band
  either side of it, so the karst fades in over about five hundred metres:
  an undulation of about nine blocks either way; karst ridges twelve high
  with flat tops and steep sides; ravines sixteen deep with two-block walls;
  round sinkholes ten deep; hummocks a block and a half high. Real-world
  headless, the floor round one spot ran over fifty-six blocks of height.
  The "verdant" programs are 432 operations and fit the eight buffers.
- **The floor** is one layered fill: moss over saturated mud, patches of
  grass and of bare mud, the clay of the ravines (as `mud`, as the river's
  clay is), deep puddles of black mud in the sinkholes and the hollows
  between hummocks, and stone outcrops on the ridge crests under a coat of
  moss. Ferns in carpets and monsteras in stands are the cover.
- **The megatrees** are ironwoods (44 to 57 blocks) and kapoks (54 to 66,
  pale `birch_log` under `oak_leaves`), one to a square of twenty blocks in
  three squares of four. A trunk two and a half to three blocks in radius
  sunk into a wider foot; five to eight buttress walls a block thick
  radiating from it, whose reach falls in three steps up their height, the
  lowest digging into the ground; pitcher plants in some of the bays between
  the walls; strips of climbing ivy up the trunk; limbs round the crown each
  with a great clump of leaves and a smaller one, with ropes of vine hung
  along them; and a TIMBER BRIDGE — one long near-level limb eighteen to
  twenty-six blocks out from the middle of the trunk, sagging and lifting
  at its end, so neighbouring megatrees' bridges cross and meet. Every
  ironwood has one, every other kapok.
- **The sub-canopy**: fan palms twelve to seventeen blocks tall with heads
  of broad three-rayed fans, and giant tree ferns ten to fifteen tall with
  long arching fronds, one to a square of seven in every other square.
- **Hollow fallen logs**: ironwood trunks twelve to eighteen long, half sunk
  in the floor and mossed along the top, with a tunnel three blocks across
  through the middle, open at both ends; the hollow is written as AIR, so
  it is clear of the ground it lies in.
- **Seven new nodes, all asked for by name**: `moss`, `black_mud`,
  `ironwood_log`, `ironwood_leaves`, `ironwood_planks`, `climbing_ivy`,
  `monstera`. The pitcher plants stand in as `ladys_mantle` until a node is
  named for them; the vines are `climbing_ivy`; the palms and ferns reuse
  the river palm's and the woodland's nodes.
- **The cut is the engine's now**: `game.schematic_shapes` (engine 2f2d18e)
  rasterises paths, ellipsoids and single blocks natively, with a
  priority per shape so wood keeps its cells from leaves and a log's hollow
  takes them from the wood. Cut in Lua, the first megatree ran a generator
  call past its instruction budget and the chunk came out air; `schem.lua`
  gained a recording mode, so the same tree code hands the shapes to the
  engine instead of testing cells. Eight megatrees are 73,811 blocks.
- **Tall structures stand whole.** The generator returned early for a chunk
  wholly over the ground, so nothing stamped into it: a megatree was cut
  off at the first chunk boundary above its roots. A scatter fill that says
  how far above the ground it reaches (`above`) now stamps into the chunks
  of air within that reach (`structures_into`, generate.lua).
- **A biome's fills compile for the chunk's own terrain mode**, not the
  biome's (`tdw.fills_for`): the woodland's turf in a "verdant" chunk has to
  be the shape of the ground the rainforest's terms moved, or it hangs in
  the air — the roof-of-turf fault again.
- **The noise, measured.** The engine's noise is clamped to +/-0.5 and
  spends a lot of time there: one octave is over 0.35 on 22% of the ground
  and at the clamp on 13%; two octaves over 0.35 on 14% and at the clamp on
  6%. The first cut's thresholds assumed a narrower spread and put black mud
  over a third of the floor. Nothing rarer than the clamp can come from one
  noise, so the sinkholes are where two independent noises are both high.
- **The twilight.** A chunk tint takes the rainforest's floor toward a
  darker emerald. **The shade is not there yet, and it is the engine's**:
  headless, 85% of the floor has a whole leaf block over it and most of
  those columns still read full sun. Two causes, both in engine-asks item
  24: foliage (`cutout`) passes light as glass does (`server/src/light.rs`,
  contract §8.2), and a chunk that loads above an already-lit one never
  darkens it. Fog, mist and drips are items 23 and 20.
- `whereami.lua`: moss, black mud, ironwood, ivy and monstera say
  rainforest, and say it over the woodland's birch and oak; `rainforest` in
  chat goes looking for it.
- Verified headless: the engine's shape tests and clippy; the mod check; the
  rainforest put everywhere (megatrees whole, floor probed); the real world
  at a fixed seed with the spawn moved into the Verdant Belt's wet half; and
  the real world at the normal spawn with three bots for ninety seconds —
  no refused program, no error, no over-budget tick.

### Pitcher Plants, kapok wood, dry and wet clay

- "pitcher plants should be Pitcher Plants; kapoks should be kapok wood,
  leaf and plank; let's add a dry clay and wet clay block." Six nodes:
  `pitcher_plant` (named "Pitcher Plants"), `kapok_wood`, `kapok_leaves`,
  `kapok_planks`, `dry_clay` and `wet_clay`, with textures (the pitchers are
  three fat tubes on a cross card; the kapok's leaves are lighter and more
  open than the ironwood's).
- The rainforest's stand-ins are gone: the pitcher plants in the megatrees'
  root bays are `pitcher_plant`, not `ladys_mantle`, and the kapoks are
  `kapok_wood` under `kapok_leaves`, not birch under oak. Headless, round the
  dev spawn: 5,056 blocks of kapok wood and 14,268 of its leaves, and no
  birch or lady's mantle left anywhere in the rainforest.
- The ravines are clay now instead of mud: `dry_clay` up their walls and
  `wet_clay` on their floors, over dry clay. 467 and 251 blocks in the same
  sample.
- The river's clay beds at the water line are `wet_clay`. They were `mud`,
  and they never showed: the bank's sand was a later code over the same
  band, so it painted over them everywhere. The clay's condition now comes
  after the sand's.
- Kapok and pitcher blocks say "rainforest" on the HUD; the clays are shared
  with the river and say nothing.
- Verified headless: the mod check; the rainforest everywhere with a block
  count; the real world with three bots; a fixed-seed world whose river
  compiled with the reordered codes (275 operations). No refused program,
  no error, no over-budget tick.

### 1.8 Deep Ocean, built and not placed

- The brief: abyssal plains 60 to 120+ blocks under the sea, trenches into
  near-bottomless chasms, flat-topped volcanic guyots, pillow-lava ridges;
  sand, white sand, mud, basalt crusts, rippled gravel drifts, fine dark sand
  round tectonic cracks with magma in them; no life on the deep plains, but
  sea growth round vents and chimneys; whale skeletons broken across basalt
  reefs, brine pools, and basalt pillars rising to within a few blocks of
  the surface. `biomes/deep_ocean.lua`.
- **Not placed, like the Coastal Cliffs.** Its sea is flat — the coast's
  level, so the two will meet — and a flat sea cannot lie on the dome.
  `tdw.config.everywhere = "deep_ocean"` shows it. Where the seas go is
  still the open question from the coast.
- **The floor** is a new terrain mode, "ocean", whose terms cancel the dome
  as the coast's do: a plain wandering between 60 and 120 blocks down;
  guyots rising 55 blocks to flat tops where a slow noise saturates; pillow
  ridges along a contour, lumpy with pillows; trenches 350 blocks deep with
  three-block walls, in stretches; basalt pillars where two noises are both
  high, topped four blocks under the surface; brine pools four blocks deep;
  cracks a block and a half wide; rippled gravel drifts. Headless the floor
  ran from 4 blocks down (a pillar's top) to 95 over a 480-block square.
- **The materials**: mud on the plains; sand patches; gravel drifts;
  `dark_basalt` on the ridges, reefs, guyot flanks, trench walls and
  pillars, all the way down their sides; white sand on the guyots' tops;
  fine dark sand round the live cracks, `magma` (it glows) in their floors
  and a moss crust near them; a salt crust round each brine pool; barnacles
  on a pillar's top near the light.
- **Life only where the brief allows it**: seagrass cover and kelp stands
  round the live cracks and on the pillars' shallow tops, and nowhere on the
  plains.
- **Structures**, cut natively: vents of one to three leaning basalt
  chimneys eight to eighteen tall with magma mouths, crusted with barnacles
  and moss and a garden of kelp and seagrass round their feet, near the
  cracks; whale skeletons 24 to 34 blocks long, the spine in three pieces
  with the middle knocked aside, ribs up the front half some missing and
  some collapsed, a skull, the jaws fallen apart, and basalt reef boulders
  half sunk round them, on the reefs.
- **Brine pools are a second fluid**, `brine` — slow, dark from inside, and
  drawn as the water block. The engine's fluids do not mix (a block holding
  one accepts none of another), so a pool laid in a hollow under the sea
  keeps the sea off it. Laid by `fill_fluid_terraced` after the sea.
- **One new node, asked for by name**: `bone`. Stand-ins until named: the
  white sand and the salt crust are `limestone`, the fine dark sand
  `black_mud`, the brine's block `water`. `magma` already existed.
- **The generator, for seas**: the sea fill is per mode now (the coast's and
  the ocean's), and runs after the structures so it takes only the room they
  leave — it used to run before them and put water inside every kelp stand
  and boulder. In the ocean mode the deep bands are measured down from the
  terrain, not the dome (`shape.BANDS_BY_TERRAIN`), or the trenches would be
  white placeholder from a hundred blocks under the dome down.
- **What the engine has to do** (docs/engine-asks.md): light does not fade
  in water (item 25), so the "total light extinction" of the plains is only
  in where things grow; and a deep sea is heavy to load (item 26) — headless,
  213 ticks in ninety seconds ran over budget with the fluid tick alone at
  45 to 100 ms, because every generated block of water is woken when its
  chunk loads.
- Verified headless: the mod check; the ocean everywhere at view distances 6
  and 16 with a floor probe; the coast everywhere again after the sea
  fill moved; and the real world with three bots — no refused program, no
  error, and in the real world no over-budget tick.

### Commands start with /, and /tp goes anywhere on the Spindle

- "Make it so I can teleport to areas on the Spindle. I'm not finding the
  biomes by flying in any meaningful amount of time. And let's have all the
  commands for this mod standardized with a / beforehand."
- **Every command is `/name args`** (`tdw.on_command` in hooks.lua, which
  replaces the bare chat words). A line that starts with `/` and names one of
  this mod's commands runs it and is swallowed; plain chat, and a `/command`
  some other mod owns, pass through untouched. `/help` lists them all. The
  old words are `/where`, `/roses`, `/crevasse` and `/stats`; `alpine`,
  `river` and the rest are gone, into `/tp`.
- **`/tp`**:
  - `/tp <biome>` — `alpine`, `woodlands`, `grasslands`, `river`,
    `rainforest` (and a few aliases: `forest`, `jungle`, `mountains`, …).
    The engine now sets the world's seed in every VM (`game.world_seed`,
    engine-asks 21), so the biome's own placement field — the mask its fills
    use — is sampled here: out from your heading round sixty-four headings
    and across the biome's rings, the first place clearly inside it. The
    river answers for itself: from a start on its rings it steps straight at
    the nearest course by the contour distance and its slope, then out onto
    the bank. Headless: the rainforest found 16.9 km away, a river bank 238
    blocks away, the alpine 6.4 km, the grassland 18.2 km.
  - `/tp <ring>` — the middle of that ring on your heading.
  - `/tp spawn`, `/tp <x> <z>` (dropped and landed on the ground), `/tp <x>
    <y> <z>` (exactly there), `/tp list`.
  - The Coastal Cliffs and the Deep Ocean answer that they are built and not
    placed, and how to see them; under the dev switch every other biome says
    it is not in that world.
  - A drop is over the highest thing that could be there — the alpine peaks
    in the cold core — and the landing aims at the ground the terrain field
    puts under you, which works in the main VM now that the seed is there.
- `tdw.config.spawn_biome` uses the same search; the old trial-and-error
  seek (drop, land, read the ground, go round again) is gone.
- Verified headless on the engine as of this afternoon (`game.world_seed`
  present): every command and alias above, plain chat and an unknown
  `/command` left alone, and the mod check.

### 1.9 Frozen Wastes, on Frostmoor

- The brief: windswept permafrost plains, jagged pressure ridges, sudden
  crevasses 15 to 30 deep with sheer blue ice walls, serac spires 10 to 25
  tall, rolling snow dunes with sastrugi aligned with the wind; snow, blue
  glacial ice and permafrost polygons; no grass, no needles, only solitary
  frozen snags and tiny copses; cryo-lakes of clear ice* over blue ice; ice
  caves under the glaciers, erratic boulders, and whiteout blizzards that
  drift snow against windward things. `biomes/frozen_wastes.lua`.
- **Where: Frostmoor, the frost ring's dry half** — the designer's choice.
  The alpine keeps the Crown and the frost ring's wet half. In the alpine's
  terrain modes ("alpine", and "all" at the frost ring's outer edge) the
  terms are now `cold_terms`: the alpine's mountains cross-faded into the
  Wastes' plains by a weight that is the ring's share past the Crown's edge
  times the dry side's past the humidity split, over a much wider humidity
  blend than the woodland/grassland one, so the range comes down to the
  plain over a kilometre or two. The "all" programs are 867 operations of
  the engine's 1,024; nothing was refused. A "frozen" mode is the dev switch.
- **The ground**: a plain rolling ten blocks either way over kilometres;
  dunes four blocks either way, drawn three times as long downwind; sastrugi
  — sharp ridges of a noise stretched six times along the wind (the
  engine's new per-axis `stretch`, now on `shape.node`'s `noise`) — on the
  snowfields; pressure ridges with jagged crests; glaciers, sheets of ice
  twelve blocks thick with steep fronts, with ice caves tunnelled through
  their thick middles a block to five and a half over the plain; crevasses
  15 to 30 deep, sheer, in stretches; flat cryo-lakes two blocks under the
  plain; and the polygons' gravel borders heaved a little over the bare
  ground.
- **The materials**: snow on the snowfields; permafrost where the wind has
  scoured it, with frost-heaved gravel (`creek_bed`) in a network of
  polygons; blue `ice` in the pressure ridges, down the glaciers' fronts and
  round their caves, and down the crevasses' walls; `clear_ice` over blue
  ice on the lakes. No cover at all.
- **Structures**, cut natively: serac clusters of two to six rough, leaning
  ice spires with shards at their feet, on the glaciers; erratics of one to
  three great half-sunk granite boulders with snow on top, on the plain;
  and rarely a frozen snag or a copse of two to four, dead wood with snow on
  the stubs and no needles.
- **Blizzards**: a square of 192 blocks is in a whiteout for ten minutes
  at a time, one square in four. There, a random tick on a snow surface
  whose next block downwind holds something that is not snow — a boulder, a
  snag, a serac, a wall — lays a layer of snow cells against that face,
  until the drift is three blocks deep.
- **The alpine stands back**: its random tick grows nothing in Frostmoor
  (`tdw.frozen_at`, the Wastes' placement field sampled with the world's
  seed and cached by eight-block square), and the HUD names Frostmoor's
  snow and ice the Frozen Wastes rather than the alpine.
- `/tp frozen` (or `wastes`, `tundra`, `frostmoor`) goes there.
- One new node, asked for by name: `clear_ice`, transparent.
- Not possible yet: slick ice walls (no friction per block — engine-asks
  27) and the whiteout's snow in the air (particles, item 20).
- Verified headless: the Wastes everywhere (488 operations; snow,
  permafrost, gravel, ice and granite at the surface); the real world at a
  fixed seed with the spawn moved to where `/tp frozen` found them (the HUD
  said Frozen Wastes; alpine and "all" programs compiled); the real world at
  the normal spawn with three bots, with and without the Wastes loaded at
  one seed — no refused program, no error, no over-budget tick.

### 2.0 Arid Mesa, on the Glass Waste's dry half

- The brief: elevated tablelands with sheer cliffs stepping down in benches
  to flat canyon floors, box canyons and buttes; rust-red*, ochre*,
  terracotta and pale tan sandstone strata; pale terracotta* caps with
  desert sandstone and rare dirt; talus of red sand, gravel and dirt at
  cliff bases; sparse crooked grey junipers* and pines; columnar cacti*,
  barrel cacti, prickly pear, sagebrush; dry arroyos with clay, sand,
  gravel, rare puddles and a palm or two; hoodoos and spires, arches over
  canyon cuts, alcoves in cliff faces, raptor nests with bone.
  `biomes/arid_mesa.lua`.
- **Where**: the Glass Waste's dry half, as the catalogue planned. The
  grassland keeps the Ember Ridge and the Glass Waste's wet half. The
  "verdant" terrain mode now covers the Glass Waste too, with the mesa's
  terms added to the dry half by a glass weight, as the rainforest's are to
  the wet half by the verdant weight: 828 operations. A "mesa" mode is the
  dev switch.
- **Not a map.** "Another excellent biome for erosion" — but a map is at
  most 1,024 samples a side and the Glass Waste is a ring 150 km round, so
  no map covers it at a useful grain. The forms erosion leaves are written as
  terms instead: five benches on a slow three-octave plateau noise, each a
  sheer cliff a block and a bit wide over a talus apron a quarter of the
  step high and six blocks out, the highest ground flat where the noise
  saturates (the buttes); box canyons along a contour in stretches, taking
  the plateau's whole height away so their floors are the plain's; arches,
  where a rare blob crosses a canyon, as the top five blocks of the plateau
  left standing over the cut; arroyos along a fine contour on the plains and
  canyon floors. If the tiled, eroded map is wanted, that is an engine
  change (a map node that repeats), and this file is where it would go.
- **The strata** are horizontal over the smooth ground (dome and relief),
  parallel to the benches: the height folded three times by absolute
  values into a zig-zag the engine's code rounding turns into rust-red,
  ochre, terracotta, pale tan and back. The first cut stepped each band and
  its code field was 1,296 operations of 1,024; the fold is one evaluation.
- **The surface**: pale terracotta caps with desert-sandstone patches and
  rare dirt on every bench top; strata down the faces; red sand on the
  plains, the canyon floors and the talus, with gravel and dirt spots in it;
  arroyos with clay banks, gravel beds and rare muddy puddles; sagebrush
  sparse on the flats.
- **Structures**, cut natively: columnar cacti five to nine tall with
  right-angle arms on the flats; barrel cacti and prickly pear clumps in the
  talus; junipers — short, crooked, often split, grey, with flat pads of
  dark needles — in the talus and singly on the tops; a palm or two by the
  washes; banded hoodoos and spires with pale terracotta caps on the plains
  and canyon floors; raptor nests of dead sticks and bleached bone just over
  the highest cliff edges; and the alcoves, hollows of air stamped at the
  feet of the three lower cliffs that carve into the face (a term for them
  needed the ground's height twice more than the program had room for).
- Six new nodes, all asked for by name: `rust_red_sandstone`,
  `ochre_sandstone`, `pale_terracotta`, `juniper_wood`, `juniper_needles`,
  `columnar_cactus`. Stand-ins until named: terracotta `dry_clay`, pale tan
  sandstone `limestone`, desert sandstone and red sand `sand`, sagebrush
  `bramble`; barrel cacti and prickly pear are the columnar cactus; the
  pines share the juniper's nodes; the palms are the river's.
- `/tp mesa` (or `desert`, `canyon`) goes there; the mesa's rock, trees and
  cacti name it on the HUD.
- Verified headless: the mesa everywhere (654 and 344 operations; a probe
  of a 300-block square found pale terracotta the commonest top, strata on
  the faces and 95 blocks of height); the real world at a fixed seed spawned
  where `/tp mesa` found it (verdant programs compiled, a river valley
  cutting through the tablelands); the normal spawn with three bots — no
  refused program, no error, no over-budget tick. One tick in the mesa run
  spent 300 ms generating a distant summary on the main thread.

### /tp brings you there

- "The /tp command does tell me where the closest biome is seemingly but it
  does not bring me there." It sent the move, and on the next tick the
  landing undid it. `game.move_player` writes the body the tick steps, but
  where a player IS (`game.entity`) is a mirror of that body taken during
  the tick, so the tick after a teleport still reads the old place — and
  the landing's first step aims the player at the ground under where they
  are, with a move of its own. That aim only runs once the world's seed is
  known in the main VM, which it has been since `game.world_seed` landed,
  so every teleport since was put straight back.
- A landing now carries its target and does nothing until the player is
  within four blocks of it, asking for the move again once a second in case
  one did not take. The join's drop to the spawn does the same.
- This was also why the headless bots never moved on a teleport; it was not
  the bot client.
- Verified headless: a bot said `/tp mesa` and landed at the mesa 10 km
  away, then `/tp river` and landed on a bank 19 km on; `/where` agreed each
  time.

### 2.1 Badlands, on the Glass Waste's wet half

- The brief: razor crests and steep fluted mud hills in a labyrinth of
  gullies, slopes of 35 to 60 degrees cut by rills into razorback fins and
  small clay canyons; wavy horizontal bands of sandstone, clay, volcanic
  ash*, charcoal* and dull lavender dried mud*; popcorn clay crust and
  chert; 95% barren, dead sagebrush* and grass only in the deep gullies,
  stunted mesa trees in drying mud; dry clay runoffs, mud-choked gully
  floors, piping voids; knife-edge ridges, mud-crack flats, petrified trunks
  bridging gullies. Not tall; a place for erosion. `biomes/badlands.lua`.
- **Where**: the Glass Waste's wet half, as the catalogue planned. The
  grassland now holds the temperate ring's dry half, the Ember Ridge, and
  the dry half from the Verdant Belt out. The "verdant" mode adds the
  badlands' terms to the Glass Waste's wet half by the glass weight: 928
  operations of 1,024, the most of any program in the world. A "badlands"
  mode is the dev switch (358).
- **The ground, as the shapes water cuts**: hills as a tent on a slow noise
  (`1 - 2|n|`, a crest and never a dome); razorback fins, a finer tent over
  their upper parts, whose crests are the knife-edge paths; rills from a
  noise stretched four times up y, so each groove runs straight down its
  slope; a labyrinth of gullies from two contours, eight blocks deep with
  flat floors; and piping voids where two 3D noises are both near zero, cut
  into the terrain field by twenty blocks, which only ever opens ground
  within twenty blocks of the surface. Headless over a 200-block square the
  ground ran over about 55 blocks of height, with a quarter of it at 45
  degrees or steeper.
- **The bands** are the mesa's fold with a two-block wave, rounded to five
  materials. Found on the way: a fold only zig-zags over zero to twice its
  first point, and the badlands' ground below the smooth height fell off the
  end and rounded to the last material, which was a third of the surface in
  dry clay. It is lifted into range first now; the five come out even.
- **The surface**: popcorn crust (dry clay) and chert (gravel) in patches
  over the bands; dry clay runoff down the lower gully walls; cracked dried
  mud on the gully floors with mud choking their middles.
- **Growth**: dead sagebrush and grass on the deep gully floors only;
  stunted mesa junipers there in a skirt of dried mud; petrified trunks
  (granite, until named) eighteen blocks long lying at the gully rims, so
  those that fell across one bridge it.
- Four new nodes, asked for by name: `volcanic_ash`, `charcoal`,
  `dried_mud`, `dead_sagebrush`. Stand-ins until named: soft sandstone
  `sand`, clay and popcorn crust `dry_clay`, chert `creek_bed`, petrified
  wood `granite`.
- `/tp badlands`; the HUD names it.
- Verified headless: the badlands everywhere with a probe of heights,
  slopes and surfaces; the real world at a fixed seed, teleported in with
  `/tp badlands` (verdant programs compiled, nothing refused); the normal
  spawn with three bots. One random-seed run had ten ticks of 100 to 1,500
  ms, all the server generating distant summaries on its main thread; the
  same seed with and without the badlands gave none and two, so they are
  not the badlands' — the summaries' main-thread generation is worth a look
  in the engine as the programs grow.

### Meadow flowers, more grass, fewer alpine firs, and /tp without the seed

- **`/tp mesa` said "the world's seed is not known yet".** The engine sets
  `game.world_seed` in the server's VM since fec84db; a client built before
  it runs its own server without it, and every `/tp <biome>` refused. It
  now searches by landing instead: the player is dropped at the middle of
  the biome's rings on one heading after another, each landing reads the
  ground it came down on, and a wrong one sends them on (sixteen headings
  at three depths into each span, the nearest span first). The reply says
  it is searching and that a rebuilt client jumps directly. The river,
  which is found from its course field, still needs the seed and says so.
  Headless with the seed hidden: the woodlands and the mesa on the first
  or second landing, the alpine and the Frozen Wastes on the second.
- A seedless landing has no aim, and a drop over the peaks either hung in
  the air waiting on ground past the vertical view or sat inside a
  mountain waiting on blocks above it, and gave up after a minute. A
  landing now steps down through the air (or up through the rock) it has
  already seen when what lies past it is not loaded, and the view follows.
- `/tp <biome>` and the search both take a biome's spans nearest first.
  The woodlands are the temperate ring's wet half and the Long Shore's, and
  the shares of the two together sent a player in the alpine 42 km out;
  now 18.
- **Grass and trees vanishing mid-chunk (river and hills)** is not in the
  generator. Headless at a fixed seed the grass cover runs 90 to 100% of
  every chunk across the spawn, the grasslands and a river valley, with no
  more one-block steps at chunk edges than inside them; the bare columns
  are the river's bed and banks. What the screenshots look like (read from
  them, not proven in the window): one-block square terraces with no trees
  and no grass are the engine's horizon summaries, one cell per block,
  which drop anything under
  a third of a block — grass, thin trunks, the part-filled top block of
  smooth ground, hence the step. They stand in for full chunks outside the
  detail range, and flying puts ground chunks a layer or two below out of
  the vertical view while the nearer layer is in it. A larger vertical view
  distance, or the ground chunks arriving sooner, is the fix; nothing to
  change in the mod.
- **Alpine firs down 75%**: the scatter's 0.28 of squares to 0.07, and the
  random tick's thickener from one surface block in 9 to one in 36.
- **More grass**: the grass noise's cut from 0.20 to 0.12 in the woodlands,
  the grasslands and the river valleys, 0.30 to 0.20 in the alpine.
- **Roman chamomile\* and blue lunaria** in every grassy biome: the
  woodlands, the grasslands, the river valleys' terraces and slopes, the
  alpine meadows. Two cover fills per biome from one helper
  (`tdw.flower_covers`, biomes.lua), from the same noise as that biome's
  grass on its other side, so a flower never stands on a tuft (the cover
  fill stacks a second run on the first inside a block); thinned by a
  second fine noise; lunaria where a slow patch noise is high, chamomile
  where it is low and a finer one clumps it. No terrain in the fields: the
  woodlands' near-ground guard is a full terrain per cell, and the grassy
  rings have no caves within a hundred blocks. Measured over 65-block
  squares: lunaria in one block in seven to fifteen, chamomile in one in
  sixty to a hundred. Lunaria a block tall, chamomile a third.
- Two new nodes: `roman_chamomile` (asked for by name) and `blue_lunaria`
  (named without the asterisk, but there was no block for it). A tone-only
  tint, so the blue and the white are not greened.
- Verified headless: the flowers in the spawn, the grasslands, the alpine
  meadows; `/tp` with and without the seed; three bots at the spawn. No
  refused program, no error, no over-budget tick outside the probes.

### Arid Mesa: ledged walls, 60% less grass; /tp by the biome's file name

- **The walls step in and out up their height** ("the mesa walls slightly
  more detailed on the vertical axis"). A noise stretched flat — features
  four blocks apart up a wall and forty along it — nudges where each cliff
  stands: the plateau value at a bench's cliff by 0.010 either way, the
  box canyons' contour by a block and a half. Headless cross-sections of
  the same walls at the same seed: a canyon wall that ran dead straight for
  thirty blocks of height now steps a block to three every few blocks, and
  the bench cliffs the same. Only the terrain's cut reads it; the aprons,
  zones and structures keep the smooth line. The verdant program is 983
  operations of 1,024.
- **60% less grass in the mesa.** Most of what reads as grass there is two
  things: the mesa's own sagebrush cards, and the river valleys' grass
  where a valley crosses the tablelands. Each is thinned by a further fine
  noise — the sagebrush everywhere in the mesa, the river's grass only
  inside the mesa's mask. Measured in cells against no thinning at the
  same seed: sagebrush 59 and 60% fewer at two places, the river's grass
  62% fewer. The cut is not the one a fine noise has at random points (0.12
  keeps 40% there, and only took 47% of the sagebrush away): the fine
  noises sampled on the same cells are not independent.
- **`/tp` takes a biome by its file's name, spaces for the underscores**:
  `/tp frozen wastes` for `frozen_wastes.lua`, `/tp arid mesa`, `/tp
  temperate woodlands`, `/tp dense rainforest canopy`. Case, underscores
  and extra spaces are ignored; the short words (`mesa`, `frozen`,
  `jungle`, `greensward`...) are gone, and a miss says how names are
  formed. `/tp list` prints the names from the catalogue. Rings stay by id.
- The biome search finishes the nearest span all the way round the
  compass before trying the next: from the mesa, the woodlands on the
  player's heading in the Long Shore (47 km) beat the temperate ring a
  quarter-turn round (14 km).

### 2.2 Taiga, on Firwold

- The brief: rolling rugged uplands and hummocky glacial ridges broken by
  sunken water-logged peat basins, slopes stepping down to flat stagnant
  hollows; rust-brown grass and mulch\*, moss, mud round the bogs, granite
  boulders under moss; a thick serrated wall of tall conical spruce on the
  ridges and slopes, dying dwarf trees in the muskeg, rare ancient pines;
  black-water channels in the peat, pools in the hollows, frost-heaved
  rubble on the crests; rare mossy fallen logs spanning the pools, lichen
  dripping from dead lower branches, mist in the forest.
  `biomes/taiga.lua`.
- **Where**: Firwold, the frost ring's wet half, as the catalogue planned.
  The alpine keeps the Crown. `cold_terms` (shape.lua) is now the alpine's
  mountains in the Crown cross-faded across its edge into the frost ring's
  two halves, which cross-fade into each other at the humidity split:
  `alpine * (1 - ring) + ring * (frozen * dry + taiga * (1 - dry))`, each
  program once.
- **The ground**: uplands on a slow noise, twenty blocks either way;
  glacial ridges as tents eleven blocks high along a contour, hummocked
  two or three blocks; basins where a second noise is high, pulled down to a
  flat floor twelve blocks under the uplands over a steep edge, with
  black-water channels cut into the peat. Headless: 63 blocks of relief
  over a 97-block square, 28% of it at 45 degrees or steeper.
- **The surface**: mulch over dirt, moss in patches under the trees,
  gravel over granite on the ridge crests, mud round the bogs, peat
  (black mud) on the basin floors with moss on their hummocks; rust-brown
  grass off the basins. Measured: half mulch, a quarter moss, a sixth peat
  and mud.
- **The pools**: the rivers' fluid fill at the basin floor's own level,
  only deep in a basin and only where the Taiga is the whole terrain (its
  cross-fades are not flat), so the water stands in the floor's dips and
  channels: 4% of a 97-block square that is half basin.
- **Growth, cut natively and stamped at generation**: spruces fourteen to
  twenty-six tall — a straight trunk, a bare foot of dead branches hung
  with lichen, tiers of branches angled steeply down round a needle core,
  a spike at the top — on a four-block grid, more than half the squares:
  needles over 57% of the ground headlessly; ancient pines forty to
  fifty-five tall with flared roots, stubbed trunks and heavy pads of
  needles, one square in five of 64; dwarf dying trees in the muskeg;
  moss-capped granite boulders; rubble on the crests; fallen giants 22 to 34
  blocks long with root plates and moss along their tops, laid over basin
  edges so they span the pools.
- **The mist**: the engine's chunk fog (`game.register_chunk_fog`, engine
  55e929d), through a new `tdw.on_chunk_fog` so other biomes can add theirs.
  Grey-green, 42 blocks of visibility (90 where the Taiga only partly covers
  a chunk), lying 14 blocks over the basin floor, so it fills the hollows
  and the ridges stand out. The floor's height is read at the height the
  last read gave, four times: the world's relief is a 3D noise, and read
  at the base dome it was three hundred blocks off.
- **Engine ed211d8**: `fill_fluid_terraced` read a level once per column at
  the chunk's floor, and a level on that 3D relief reads several blocks low
  there and differently per chunk layer, so the Taiga's pools showed only
  where a basin floor sat low in its layer. It now re-reads at the level and
  extrapolates to the fixed point. The river valleys' levels are the same
  kind and get the same correction.
- **A seam fixed on the way**: the frost ring is terrain mode "alpine"
  inside a radius and "all" outside it, and the world's detail noise was in
  one and not the other — up to three blocks of step on that chunk line.
  "all" now fades the detail out with the alpine weight.
- **A new terrain mode, "rim"**: the Taiga took the "all" programs to 968
  operations and the woodlands' grass (the terrain and a mask) to 1,031 of
  1,024, so the temperate edge of the frost ring failed to generate. Past
  the Crown's reach the cold terms are the frost ring's halves alone:
  "rim", 759 operations; "all" keeps the band nearer the Crown, where the
  temperate ring's biomes never are.
- `/tp taiga`. `/tp` asks a narrow span for less margin inside its field:
  the alpine, now the Crown alone, is never 0.01 inside its own and
  `/tp alpine highlands` found nothing. The HUD names the Taiga from its
  placement field, since its ground is fir, moss and peat that the alpine
  and the rainforest claim; the alpine's random tick stays out of it.
- Three new nodes: `mulch` (asked for by name), `rust_grass` and
  `hanging_lichen` (named in the brief with nothing to stand in for them).
  Stand-ins until named: spruce and pine `fir_log` and `fir_needles`, peat
  `black_mud`, rubble `granite` and `creek_bed`.
- Verified headless: `/tp taiga` with a probe of relief, surfaces, growth,
  pools and a spruce's cross-section; the temperate edge in "rim" with
  woodland and grassland fills compiled; `/tp alpine highlands`, `/tp
  frozen wastes`; three bots at the spawn. No refused program, no error.

### After a teleport: the Verdant Belt generated as air, white under the hills, and what the stand-ins are

- Reported from the window (2026-09-15): `/tp` to most biomes showed
  "giant solid chunks of dirt, stone with a couple of trees or rocks on
  them"; the rainforest "blank default nodes in giant full chunks above
  and below"; the woodlands "all default node white at a slope with grass
  on it". Three different things.
- **The Verdant Belt and the Glass Waste's edges had generated as AIR
  since the badlands (2.1).** The grasslands' fills each carried the whole
  terrain plus their mask, and in the "verdant" terrain mode (928
  operations then, 983 with the mesa's ledged walls) that was 1,033 to
  1,070 of the engine's 1,024: refused, so every chunk with the grasslands
  present — the whole Verdant Belt, the Glass Waste's edges — failed and
  fell back to air. The mesa's own probes never met it: the grasslands are
  not in the Glass Waste. Found with the new `bot.chunk_report` (below).
- **Fixed by the rewrite the newer biomes already had**: the woodlands and
  the grasslands are one layered fill each (`fill_layers`: the terrain
  once, and a code field of noises with no terrain in it — turf, litter,
  creek bed; turf, trails, bared crests), where they were five and three
  fills each of the whole terrain. The ferns are a cover two cells tall,
  as the tufts are. The covers' near-ground guard — a full terrain per
  cell, to keep grass off cave floors a hundred blocks under the first
  cave — is gone. The heaviest woodland or grassland program is now the
  terrain itself; a chunk of woodland evaluates the terrain three times
  where it did seven.
- A fill's mask now leaves out the spans its terrain mode can never meet
  (`shape.mode_u_ranges`): the grasslands' temperate-ring span is not in
  the "verdant" programs.
- **Valleys filled solid with white.** The surface band — the hundred
  blocks under which everything unbuilt is the white placeholder — was
  measured from the base dome, and the fill that paints it painted
  everything under that plane, air included: wherever the world's relief
  (a hundred and fifty blocks either way outside the Crown) took a valley
  more than a hundred blocks under the dome, it was filled solid with
  white up to a flat plane, and the grass and trees were then laid on the
  real ground inside it — a white slope with grass on it, and giant flat
  solid chunks. The spawn's plain flattens the relief, so it never showed
  there. The band is measured from the terrain in every mode now, as the
  ocean's already was. Measured at a relief low 121 blocks under the dome
  (`/tp 20000 -3000` at seed 12345): 34 surface columns flat to a chunk
  face with white under them before, 113 real surfaces with stone under
  them after.
- **The solid chunks with a tree on them are the horizon's stand-ins**,
  drawn while the real chunks stream in: a long teleport drops every
  chunk the client held, and the detail radius takes forty-five seconds
  or so to fill at a view of six on this machine (summaries arrive first,
  and are one material a cell). Measured from the client's side with
  `bot.chunk_report`: at every biome, 45 seconds after `/tp`, the client
  holds 113 surface chunks of real mixed terrain under sky and none flat
  to a chunk face; no summary lies inside the detail cylinder. Nothing to
  fix in the mod; the wait is the generator's, and the stand-ins are the
  engine's answer to it.
- **Engine, the bot**: `bot.chunk_report(view)` says what a client holds
  within `view` chunks of where the server last put it — full chunks,
  summaries by level, unloads; the full ones decoded and classed as air,
  one material or mixed; how many surface chunks are mixed (terrain) or
  flat to a chunk face; and what the one-material chunks under the
  surface are made of. What a player SEES after a teleport is this, not
  what the server generated.
- Verified headless: `/tp` to all ten biomes with the report (real terrain
  at each, no refused program, no failed chunk); the covers at the spawn,
  the grasslands, the Verdant Belt and a woodland by a river (ferns,
  tufts, flowers, litter and loam under the turf).

### The seas: a third of the world, in terraced arcs along the rings

- The decision (2026-09-15): "Do what you think is best with the sea
  sizing. Obviously we will have to terrace the seas, and they can be a lot
  longer than they are wide. Whatever the numbers say is most natural. Two
  thirds land, one third sea." `seas.lua`; the Coastal Cliffs (1.4) and
  the Deep Ocean (1.8) are placed.
- **The numbers.** The dome's slope is never more than 6.5% (at r = 34 km)
  and never under 3.9% outside the cold core, so a flat sea a kilometre
  across the slope has forty to sixty-five blocks of dome between its two
  shores — and along a ring the dome is level. So the seas are long ARCS
  along the rings, in five LANES (r = 19.1, 32.7, 39.6, 46.9 and 54.3 km;
  4.1 to 5.5 km wide), which is the world's own idiom; and across a lane a
  sea is TERRACED: the dome's height quantised in steps of sixty blocks,
  every pool at one of those levels, a SILL of land between — a strip 260
  blocks wide standing at the upper pool's level plus a beach, with a bank
  sixty blocks over a hundred down into the lower pool past its outer
  edge. The steps are circles of constant radius, shared by every sea. A
  pool's level is the dome at its inner edge less half a step: the inner
  shore stands thirty blocks over the water, the outer thirty under it,
  and the ground is floored up to it.
- **A third.** The arcs are where either of two nine-kilometre noises is
  positive (three quarters of a lane), their edges wandering by a couple
  of hundred blocks, bays and headlands on that at a seven-hundred-block
  scale and the coast's own bites and crenellations under it. Measured
  headless over forty thousand points of the disc: 38.3% at the first
  widths, 33.3% with them cut by an eighth, 26.0% once the sills were
  widened, 33.1% with the lanes a quarter wider. None in the cold core (the
  alpine map and the Wastes are not built for a shore), none across the
  Glass Waste — the world's dry band, and the terrain program that could
  not carry a shore beside its own — and none on the spawn's plain.
- **The maps.** Three, 1,024 samples a side at 116 blocks, filled once when
  the world opens: the signed distance to the nearest shore (blocks,
  positive at sea), the pool's level (km over Y0), and the level over the
  dome. A density program cannot quantise, and five lanes and forty-one
  steps and sills are nine hundred operations a map pays once and a
  program reads in two. The sills are in the distance map, wider than two
  samples so none is ever missed (a missed sill is two pools sixty blocks
  apart with nothing between), and the level map's step sits at a sill's
  outer edge, not its circle, so the sill is the upper pool's the whole
  way across and the map's one-sample ramp between levels lies in the
  lower pool, where the seabed follows it down as a bank. The water's
  level is the map's rounded DOWN to a step, so the ramp never stands a
  strip of the upper pool's water in the lower. (The first cut had
  sixty-block sills as terms of the radius in every program, with the
  ramp inside them: the land beside a sill was lifted to the ramping
  level, up to thirty blocks under the upper pool, and the water flooded
  it with the woodland's trees under it — seen from the window.)
- **The shore** (`shape.coast_shore`, coastal_cliffs.lua): the ring's own
  terrain with the sea's shape on it. The hills stay and the basins go —
  the ground is never under a floor that is the pool's level plus a beach
  for 130 blocks inland (a sill, whole) and falls away from there at one
  in two, so a hill meets the sea as a cliff its own height and a basin as
  a coastal plain at the water's height with a bank down behind it (the
  first cut faded ALL the relief out, and every shore was a two-block
  beach behind a one-in-twenty slope; the second measured the floor from
  the dome, and the land twenty blocks in could stand twelve under the
  water behind a rim the width of a dyke); from the coastline the coast's face
  rises over two blocks (twenty-eight on a beach) from the shelf's edge
  to that ground; the jag and the cuts — the notch, the sea caves, the
  flooded tunnels — go on. The blowholes and the finest
  jag rib went: a shore program carries the ring's terms as well now, and
  they were the least of the cuts for what they cost (the blowholes
  wanted particles anyway). Past the shelf (`shape.sea_deep`) the shelf's
  foot blends into the ocean's floor between 130 and 200 blocks out.
- **Terrain modes.** A chunk within 620 blocks of a shore is
  "<mode>_shore", past the shelf "deep"; and "verdant" split:
  "glass" (the mesa and the badlands over the temperate pair, 912
  operations) for the Glass Waste, "belt" (the rainforest over the pair,
  432) for the Verdant Belt and outward, "verdant" (all three, 983) only
  for the band where they meet, which has no seas. The temperate shore is
  786 operations, the belt's about 860, the deep 323.
- **The water** is the engine's terraced fluid at the pool's level, the
  map's level rounded down to a step in the program, within the shore,
  asked of every chunk inside the body — the maps' bounds
  answer for nothing where no sea reaches. Rivers peter out over the 600
  blocks before a shore: a valley cut through the rim would drain the sea.
- **The biomes.** The coast is present in every shore and deep chunk, its
  ground the last 24 blocks of land (its turf, whatever the height: the
  strata are the face's, and on a sloping shore they came out as bands
  across the ground — seen from the window) and the shelf; the ocean past
  the shelf. Both read the sea maps, not a ring. The woodlands', grasslands',
  rainforest's and river's covers, stands and layers keep 20 blocks off
  the sea. `/tp coastal cliffs` lands on a cliff top, `/tp deep ocean` on
  the floor of a pool; the HUD names both from the map.
- Engine `register_on_world_init` is one per mod (a second registration
  replaces the first, which is how the seas' maps went unbuilt on the
  first run): `tdw.on_world_init` in hooks.lua multiplexes it, and the
  alpine's maps and the seas' both subscribe.
- **A new world.** The maps are built once in a world's life, when it
  opens; a world opened before this has none, and no seas.
- Verified headless: the fraction; `/tp coastal cliffs` (a hill meets the
  water as a 46-block cliff; the shelf two to twelve under over eighty
  blocks, a sandbar breaking the surface at twenty-eight; the coastal
  plain behind a low shore at the water's height plus three); `/tp deep
  ocean` (the floor 26 to 90 and more under a pool's surface twelve
  kilometres away); profiles across a sill and both its edges; the
  circuit of every biome with the client-side chunk report; three bots.
  No refused program.

### The mod disabled at a spawn with a river: the river's and the coast's trees cut natively

- From the designer's server log (2026-09-15, their own seed): "building
  the fills of river_valleys in mode temperate_shore failed: instruction
  budget exceeded" at the spawn chunk, then "disabling mod after
  generation failure". A mod past a generator call's instruction budget
  is disabled, and every chunk after that is the engine's fallback — the
  solid, minable slabs with mobs on them that read as "unloaded chunks",
  and the water standing over woodland where the sea's chunks had been
  laid before the land's.
- The cause: the spawn is now a shore-class chunk (its plain is 350
  blocks from the nearest possible shore, inside the 620-block band), and
  a river runs through their spawn. The first chunk to compile a biome's
  fills in a mode compiles them in that generator call, and the river's
  compile CUT its willows, palms and drift piles — rasterised in Lua, tens
  of thousands of instructions a tree — in the same call as the coast's
  ten pines (the same) and the woodlands', grasslands' and coast's
  programs. Over the budget. The headless seed had no river at the spawn
  and never met it.
- The river's trees and the coast's pines are recorded and cut natively
  now (`schem.record_begin`, `game.schematic_shapes`), as every biome
  since the rainforest's has done. Verified at the designer's seed: the
  spawn, `/tp coastal cliffs` (their exact landing, 16599, 0) and `/tp
  river valleys` generate, every fill compiles, no budget failure.
- `bot.chunk_report` (engine) now tells a one-material chunk under water
  from one under air: a seabed a few blocks under the surface fills a
  chunk layer whole, and was counted as a slab.
- New engine ask (28): the horizon's summaries carry no fluid, so from
  outside the detail radius a sea is its floor, a hole in the world the
  shape of the pool; and in light mode 3 the water is drawn as one
  translucent volume with the chunk seams showing through it.

### The name always up, the lanes off the rainforest, a calmer badlands, a smoothed and fogged Frostmoor

- **The biome's name stays on the HUD** ("for now at least let's have the
  biome always displayed"): it changes when the ground does and never
  goes away.
- **The rainforest was under a sea.** The second lane ran through the
  middle of the Verdant Belt (28.3 to 35.4 km, the lane 30.7 to 34.8) and
  drowned most of the rainforest; `/tp dense rainforest canopy` found the
  rainforest's field positive on a pool's floor and put the player there.
  Four lanes now: the temperate ring's, wider and reaching into the Ember
  Ridge (16.3 to 22.5 km); one straddling the Belt's outer edge (34.2 to
  39.0); two across the Long Shore and the Hem (41.6 to 48.0, 50.1 to
  56.7). The Belt keeps 29 to 34 km of rainforest and grassland. The same
  third of the disc, measured. And `/tp` to a land biome lands on land: a
  place is taken only 150 blocks or more back from any shore.
- **Alpine boulders cut to 70%**: one surface tick in 29 grows one, was
  one in 20.
- **Grass under water** has an air pocket round it because the engine's
  fluid fills a block to twenty-seven cells less the cells it holds, and
  a tuft's cells count. The mod cannot put water where a plant's cell is;
  engine ask 29. The land biomes' covers keep out of the water already.
- **Badlands**: the rills (a 3D noise) and the piping voids left clumps
  floating; the rills cut by half, the voids smaller and shallower. A
  dusty orange-brown tint on every tinted material in its chunks, and a
  dust haze (110 blocks of visibility, 220 at its edges), through a new
  `tdw.on_chunk_tint` that lets more than one biome colour the world
  (the engine keeps one tint hook per mod, as with the fog; the
  rainforest's moved onto it).
- **Frozen Wastes smoothed**: the plain from ten blocks either way to
  five or six, the dunes from four to under two, the sastrugi and the
  polygons' heave halved, the pressure ridges from nine blocks to five
  with a third of the jag. The snags to 15% of what they were. A whiteout
  — thick white-blue-grey fog, 26 blocks of visibility, 70 at the edges —
  over the whole of Frostmoor.

### 2.3 Volcanic Foothills, on the Ember Ridge

- **The Ember Ridge is the Volcanic Foothills** (`biomes/volcanic_foothills.lua`),
  both halves, 20.7 to 24.8 km, taken from the grassland that stood in.
  The brief: steep stepped basalt terraces and jagged cinder cones with
  inclined stone aprons; low foothills rising to sharp ridges broken by
  lava levees and deep gouges; dark basalt, porous lava rock*, slate-grey
  ash*, pumice* pebbles, sulfur* crusts ringing thermal fissures; very
  sparse trees, none on fresh lava, clustered in ash pockets and hollows,
  charred snags and fire-scarred pines of charcoal*; ash scree, rain-cut
  ash gullies through tuff, fissures venting steam; columnar basalt,
  hollow lava-tube blisters, smouldering fumaroles with magma, jagged
  lava boulders in the ash flats.
- **The shape**, a new `"ember"` terrain mode (shape.lua): the temperate
  pair with the ridge's terms weighted in over the ring's inner edge and
  out again across its outer third, because the Glass Waste's programs
  begin at the ring's outer edge with the mesa's terms and have no room
  for these (the mesa's now start 800 m inside the Waste, `GLASS_INSET_U`,
  where it is plains anyway). Foothills of three blocks either way;
  ridges forty-two blocks tall as tents over a contour, climbing in
  seven-block terraces; cinder cones fifty-five blocks tall where two
  noises agree, a crater in each top, a softer-edged apron round each
  foot; lava levees four high along a contour, in stretches; gouges
  sixteen deep; ash gullies where a tuff noise says; fissures a block
  wide and six deep, in stretches. 605 ops.
- **The ground**, layered codes: basalt; ash drifts and gully floors;
  pumice pebbles; cone scree (the flanks between a quarter and seven
  tenths of the cone's weight); lava lobes where a lobe noise is high;
  a sulfur ring round every fissure. Steam rises off the sulfur through
  a random tick (`game.emit_particles`, lifting).
- **Structures**, cut natively: columnar basalt clusters on the ridges,
  blisters (an ellipsoid of air under a one-block crust) and fumaroles (a
  magma throat, a sulfur ring) and lava boulders on the flats, charcoal
  snags in the ash pockets, charcoal-based pines with fir needles in the
  hollows, never on a lobe.
- **New nodes**: `lava_rock`, `pumice`, `sulfur`. The ash is the
  badlands' `volcanic_ash`, the charred wood the badlands' `charcoal`.
- **The HUD** says "Volcanic Foothills" on the ridge: its basalt is the
  coast's material, so `tdw.volcanic_at` (the placement field, cached by
  eight-block square, as `tdw.taiga_at`) decides before the ground does.
- **The first sea lane pulled in** to 16.3 to 19.1 km: its shore's
  reach (920 blocks) now ends short of the ridge's first chunk at 19.5,
  because the ridge's terms and the shore's together are 1030 ops, six
  over the compiler's cap, and the brief has the fissures venting steam,
  not pooling water. The second and third lanes a few hundred metres
  wider (34.1 to 39.5 and 41.1 to 48.5, both away from the rainforest)
  for the same third of the disc: 0.332 measured.
- Checked headless on a fresh world: `/tp volcanic foothills` lands on
  the ridge (the HUD says so), the surface under the bot is ash, basalt,
  lava rock, pumice, sulfur, magma and charcoal, the cones' height map
  shows forty blocks of relief, and the coast, mesa and 20 km (now
  woodland, dry) come up whole; no errors, nothing refused. **A fresh
  world is needed**: the sea maps are filled once, at world init.

### The rivers back, the Jungle, lava, and a round of look-and-feel

- **The rivers had no water and no valley anywhere in a sea mode** ("the
  rivers seem to be filled in", with "a very harsh line"). The sea
  distance map was clamped at 400 blocks and the shore class reaches 920,
  so EVERY land chunk in the temperate, belt and coast modes read as
  within reach of a shore: the whole of every ring ran the shore program
  (797 ops, not 361), and `seas.near()`, which lifts the river trough
  toward a shore, never fell under 0.56 — the trough was lifted 560
  blocks everywhere, and the river's bed and irises were painted on the
  uplands where its valley should have been. Where a sea mode met one
  that is not (the Ember Ridge, the Glass Waste) the valley dropped 27
  blocks at the chunk line: the harsh line. The clamp is 1,100 now
  (`seas.DIST_FAR`). Headless, on a live reach: 1,606 blocks of water in
  the channel, 27 blocks of valley.
- **The river's fade toward a shore is gentle now**: the trough is lifted
  60 blocks over the 900-block band (`shape.RIVER_LIFT_KM`), not a
  kilometre, so a valley shallows and is gone half way across it instead
  of ending in a wall; the river's bed, banks and trees stop where the
  valley is gone, and its irises and glow caps where the water does.
  `/tp river valleys` lands on a live reach, not in the band.
- **Jungle**: the Dense Rainforest Canopy renamed (`biomes/jungle.lua`,
  `/tp jungle`). Its megatrees' roots are PATHS now — each leaves the
  trunk a few blocks up at half its width, out and down with a kink at
  the knee, thinning to a tip that dives under, with a side root off most
  — gnarly, not the staircase-edged walls. The leaf clumps a fifth bigger
  and each a core with two or three rough ellipsoids thrown off it, their
  own sizes and flatness. The vines hang two links from a limb and grow
  the rest a link at a time (a random tick on a hanging ivy block starts
  it; a link every thirty ticks to twelve). The HUD says Jungle in its
  clay ravines and mud hollows too (`tdw.jungle_at`).
- **Lava**: a fluid (`lava`, tick rate 10, lit orange) and where it lies
  in the Volcanic Foothills — very rare pits (two noises both high) and
  channels along a contour in rare stretches, the ground capped down to a
  flat floor eight blocks under the foothills where they are, lava four
  deep over lava rock, by the terraced fluid fill the rivers use. Two
  pits found headless at seed 12345 (`-5508,20161`, `-14871,14685`), one
  6,443 blocks of lava. The ridges back a fifth (34 blocks, cones 45), a
  fine grain of a block and a half over everything. 666 ops.
- **Sulfur glows** a little (`light_emit` 3/2/0). **Very rare spots of
  it in the Arid Mesa**, on the flats. **Glow caps**: bioluminescent
  mushrooms (blue-green light 2/6/8) sparse on the river's wet banks.
- **Alpine**: more grass on the permafrost and dirt (TUFT_MIN 0.20 to
  0.13). **Arid Mesa**: the walls' ledge noise from ten blocks to six and
  the canyon's from three to two — it cut the little mesas through and
  left their caps floating; half the big cacti; the badlands' dust haze
  over it. **Badlands**: the fins, hills, waves and rills a fifth to a
  quarter calmer; the dust a quarter of its strength (visibility 440/880).
  **Frozen Wastes**: the whiteout a third of its strength (78/210), twice
  the snags again (0.045), a little of the alpine's grass on the bare
  permafrost. **Taiga**: the uplands, ridges, hummocks, basins and
  channels all 45% smaller; the mist 15% of its strength (280/600).
  **Temperate Woodlands**: the leaf-litter patches ("the mud spots") from
  a dozen blocks to five or six, and a tenth of the ground, not a fifth.
- **The coast's turf is gone** ("i did not ok that block"): the rim is
  moss with the temperate grass on it; `coast_turf` and `coast_grass`
  removed. The jag on the face a third of what it was, on land only (it
  was thrown either side of the line and lifted the seabed into ribs that
  read as floating), fewer arches, the cuts shallower.
- Checked headless on a fresh world: rivers, jungle, coast, volcanic (with
  a pit), mesa; the HUD right everywhere; nothing refused, no errors.
  **A fresh world is needed** (the sea maps are filled at world init).

### 2.4 Coral-Fringed Shallows, 2.5 The Dunes, 2.6 Flower Forest

Three biomes from one brief, and a mode fault they turned up.

- **The `"ember"` terrain mode had no outer edge** (2.3, this morning), so
  every chunk beyond the Glass Waste — the Long Shore and the Hem, 28 km to
  the rim, a third of the world — was generated with the Ember Ridge's
  programs. The ground was right (the ridge's terms weigh nothing that far
  out), but the mode's u range is the ridge alone, so `biome_mask` pruned
  every span out there to nothing: the woodland, the grassland and both new
  land biomes painted no surface at all and the outer world was bare soil.
  The test now also asks that the chunk be inside the Glass Waste's own
  programs' inner edge. Found because the two new biomes would not paint.
- **2.4 Coral-Fringed Shallows** (`biomes/coral_fringed_shallows.lua`), the
  second sea lane — 34.1 to 39.5 km, the warm water off Goldwater. Lagoon
  flats one to five blocks under the surface, a barrier crest ninety blocks
  out standing at about the waterline, and past it the shelf's own ledge
  dropping thirty blocks into the Deep Ocean. Surge channels cut the flats
  and the crest; tidal gutters scour gravel across them; sandbars rise, and
  the rare spit breaches the tide. White sand, gravel, calcite, rare pumice,
  and pink algae over most of the reef rock. Elkhorn, table and brain
  corals in magenta, cyan and amber; swim-through arches; hollow limestone
  bomboras; anemone carpets down the drop-off wall; leaning palms on the
  dry spits only. **It costs the shore programs no mode of their own**: the
  reef's floor is offered to `shape.coast_shore` as a field that is its own
  bed inside the lane and a kilometre under the world outside it, and the
  shore takes the greater of the two — one operation and one buffer. Every
  other lane is still the Coastal Cliffs, which keep the land side of this
  one (the beach, the face and the turf behind it).
- **2.5 The Dunes** (`biomes/dunes.lua`), Goldwater — the Long Shore's dry
  half, 35.4 to 50.1 km, taken from the grassland. Barchan dunes from
  `min(up, down)` of two clamps on one wind-stretched noise, so the ground
  climbs two hundred blocks and drops in thirty; long rhythmic swells under
  them; flat deflation basins where the dune field's own gate is low, with
  coarse lag and a wind-packed crust; yardang rock ribs along a contour.
  Barren: no timber, a little sagebrush and hardy grass in a few of the
  hollows, bleached megafauna ribcages half-swallowed on the dune flanks,
  dead snags, wind-carved rocks. No new nodes.
- **2.6 Flower Forest** (`biomes/flower_forest.lua`), the Long Shore's wet
  half, taken from the woodland. Parkland: groves of six to fourteen apple,
  cherry and birch with sunlit clearings between them, over lush grass,
  mulch patches and moss-dusted stones. **The flowers come in sweeping
  bands**: four cover fills share one slow wave noise and each takes a band
  of it, overlapping at the edges, so a walk crosses allium, poppy, peony
  and bluebell in sweeps a hundred blocks wide. Brooks are the existing
  gullies' floors with water laid in the deepest quarter of them — pebble
  beds, grassy banks, no channel cut — and spring seeps pool in the
  hollows. Fallen rotting blossom logs. It adds one term to the terrain: a
  six-block knoll noise.
- **New nodes**: `pink_algae`, `coral_magenta`, `coral_cyan`, `coral_amber`,
  `white_sand`, `calcite`, `sea_anemone`; `apple_wood`, `apple_leaves`,
  `apple_blossom`, `cherry_wood`, `cherry_leaves`, `cherry_blossom`,
  `birch_leaves`; `allium`, `peony`, `poppy`, `bluebell`.
- Checked headless on a fresh world: every biome teleported to and read on
  the ground — the lagoon is 3,228 wet columns of white sand, algae and
  coral under six blocks of water; the dunes are sand, lag and crust with
  18% cover cut to a few per cent; the flower forest is peony, bluebell,
  poppy, allium, blossom and grass under cherry and apple crowns. Nothing
  refused, no errors; `temperate_shore` 985 operations of 1,024,
  `belt_shore` 939. **A fresh world is needed.**
- **Three engine asks written** (`docs/engine-asks.md`): 30, a program
  cannot spend the same value twice — the shore programs are at 985 of
  1,024 operations and every helper called twice is compiled twice, which
  is what cut the reef's tidal gutters and what keeps the rim's thinner
  programs biome-less; 31, a fluid gives no light — measured in a pit, a
  block holding 21 cells of lava reads r0 g0 b0, so molten rock is black
  at night; 32, a cover fill is one block tall, and the brief asked for
  two-block flowers. Items 20 (particles) and 22 (stretched noise) are
  marked landed: the fumaroles and the barchans use them.
- **Found, not fixed**: past about 54 km the chunks are no longer wholly
  inside the body, so the generator uses the `flank` programs, whose
  terrain is not the one the biome fills carry — nothing paints there and
  the Hem's outer half is bare. It predates this batch and wants a batch of
  its own.

### The half that moved with height, the sea floor's palm trees, and a round of trims

- **The wet/dry split moved with height, and `/tp` landed on the wrong
  side of it** ("I tp to frozen wastes and end up in clear taiga"). The
  humidity is a 3D noise at 1/9000 with two octaves, and everything that
  asks which half of a ring a place is samples it at a different height:
  `/tp` and the HUD at the base dome, a fill at the block it paints, which
  the relief puts up to four hundred blocks away — a tenth of a period,
  more than the blend either side of the split. So the generator and the
  HUD could disagree about which biome a place was, and they did. The
  humidity and the ring wobble are stretched a thousand times in y now
  (engine 12bd662), which makes them the same field at every height a
  player can stand.
- **Palm trees under the ocean**: the river's gate against the sea only
  ran in the shore modes, so in the "deep" programs its bed, banks, grass,
  willows and palms were laid on the ocean floor. The gate is in every
  mode now, and a river is not present past a shelf at all. The woodland,
  the grassland, the Dunes and the Flower Forest were painting their turf
  under the water for the same reason — their code fields had the ring
  mask but no sea exclusion — so the seabed was grass in places. Fixed.
- **The beach was a sheared-off stone pad.** The coast met the water in a
  two-block vertical face everywhere except the tenth of it the beach
  noise picked. Half the coast is a beach now (the noise's cut from 0.22
  to 0.02), the ramp is 34 blocks wide, the face where the rock does stand
  is 4 blocks rather than 2, the beach's gravel reaches 30 blocks in
  instead of 14, and the pines start 12 blocks back from the water instead
  of 3.
- **The Dunes are 91% sand**, measured over an 89-block square: the
  deflation basins take a fifth of the sand sea at most, their lag and
  crust are a corner of a basin each, the yardangs are down to the ribs'
  spines, and what little grows is down to a few per cent. The shape is
  the dunes and the swells, as asked.
- **Badlands halved again**: hills, fins, rills, gullies, the long wave and
  the piping voids are all half what they were this morning, which is a
  quarter of the first cut.
- **Cherry leaves are pink** (and keep their own tint rather than the
  green one, which was pulling them back toward the canopy's colour).
- **Fewer of things**: river courses 4.5 km apart rather than 2.6 ("river
  valleys seems excessively common"); the rivers' palms to 30%; the Frozen
  Wastes' seracs to a quarter, and the grass I added there yesterday from
  a third of Frostmoor to 6% — at one octave a fine noise sits AT the
  clamp about an eighth of the time, so a threshold near 0.5 still takes
  an eighth of the ground; two octaves and a patch noise fix it. The
  grassland's bare crests are a tenth the area and a third the size ("the
  mud swatches are still way too big").
- **The HUD asks the Dunes last**, after the ground's own materials: sand,
  sandstone and gravel are the coast's and the mesa's too, and standing on
  a beach inside their ring it used to say Dunes.

### Provinces: two biomes to a ring's half

- **A ring's half was one biome all the way round**, which is a five to
  fifteen kilometre walk through one thing. A second slow noise
  (`shape.province_mask`, 1/3000, stretched flat in y like the humidity)
  cuts each half again into patches two or three kilometres across, and the
  two biomes that share the half take one side each:
  - the Long Shore and the Hem, dry side: **The Dunes** and the **Rolling
    Grasslands** in turn;
  - the mild rings' wet side — the Greensward, the Long Shore and the Hem —
    the **Flower Forest** and the **Temperate Woodlands** in turn.
  Measured: walking 32 km around the Long Shore now crosses eleven biome
  boundaries, a change every 2.3 km on average, where before it crossed
  one or two. The Flower Forest reaches the spawn ring for the first time.
- **The terms follow the materials.** The Dunes' barchans are thirteen
  blocks tall, so their weight is gated by the province too and the sand
  starts exactly where the dune field rises (six operations, and
  `temperate_shore` is at 993 of the compiler's 1,024). The Flower Forest's
  knolls are six blocks of gentle roll, so they are NOT gated — the
  woodland reads no differently for having them, and that saves the six.
- **The HUD asks the masks when the ground cannot say.** Four biomes now
  share grass, loam, dirt, mulch and moss, so a bare patch of turf no
  longer names a biome: `tdw.placed_at` samples the biome's own placement
  field, cached by eight-block square, and a material one biome owns alone
  — a poppy, an apple tree, leaf litter, sand — still decides above it.
- **`/tp` stays inside 52 km.** The Hem's spans run to the rim, but past
  about 54 km the chunks leave the body, the generator uses its flank
  programs and nothing paints: `/tp dunes` was landing on bare placeholder
  62 km out.

### The middle of the world, and a wobble that was worth kilometres

Found by sampling the whole disc on a grid to draw a map of it.

- **The centre was unclaimed.** A ring band is `half - |u - mid|`, zero at
  both edges — and the Crown's inner edge is the axis, so the alpine mask
  fell to nothing exactly at the middle of the world. The innermost ring
  is mirrored through zero now, so its band is widest at the axis.
- **The ring wobble was a fixed amount of u, which is not a fixed amount of
  ground.** u is r squared over R squared: 0.010 of it was 580 m at 30 km,
  3.5 km at the Crown's edge, and more than the whole Crown at the axis.
  That is why the middle of the world was patchy even after the first fix,
  and why the Taiga and the Frozen Wastes traded places over kilometres.
  It is a share of the radius now — two per cent either way, so 600 m at
  30 km and 94 m at the Crown's edge — which costs two operations, since
  `u * (1 + noise)` still evaluates the radius once. `temperate_shore` is
  at 999 of 1,024.
- Measured over the whole disc afterwards: Deep Ocean 22.8%, Rolling
  Grasslands 16.0%, Temperate Woodlands 11.7%, Flower Forest 11.5%,
  Coastal Cliffs 7.6%, The Dunes 6.9%, Jungle 6.1%, Volcanic Foothills
  5.3%, Badlands 2.8%, Coral-Fringed Shallows 2.6%, Arid Mesa 2.6%, Taiga
  1.8%, Frozen Wastes 0.8%, Alpine Highlands 0.7%. The 0.9% left over is
  the outermost sliver, past where anything paints.

### The Flower Forest reads as meadow, not carpet

- **Flowers and grass cut by about half each** ("reduce the amount of
  flowers and grass in the flower forest by 60%"). Measured over the same
  89-block square before and after: flowers 40% of the ground to 20%,
  tall grass 26% to 14%, with bare turf, mulch and moss showing through
  where they were. A higher threshold alone could not do it — one octave
  of a fine noise sits AT its clamp about an eighth of the time, so
  raising the cut from 0.20 to 0.35 took only a third away — so both are
  thinned by a second, independent noise instead, which multiplies
  cleanly.
- **The clearings are about three quarters wider**: the grove noise is
  slower (1/95 rather than 1/72) and its cut higher, so the groves come
  out the same size with more sunlit ground between them.

### The cold core swapped, and three more biomes: Icefall, Silverwood, Salt Pan

- **The Frozen Wastes are the ice cap now and the Alpine Highlands stand
  round it** ("the alpine highlands and frozen wastes need to switch
  spots"): the Crown is the Wastes' permafrost plain, split by the
  province noise with the new **Icefall** — the same ground dressed as
  the glacier itself: blue ice cracked into polygons, clear ice down into
  the crevasses and over the frozen lakes, moraine bands, seracs and
  fallen blocks standing dense, a thin bright haze. Frostmoor, the frost
  ring's dry half, is the alpine's mountains; the alpine map is twelve
  kilometres from the axis either way, so it reaches. In shape.lua the
  swap is `frozen * (1 - ring) + ring * (alpine * dry + taiga * (1 -
  dry))` — the same programs and weights the other way round. The cold
  core's HUD asks the five placement fields in order, since snow, ice,
  permafrost, granite, fir and moss are shared between them.
- **Silverwood**, Firwold's other half ("I need a second biome in taiga
  too"): birch and aspen in loose stands on a lichen floor, mulch under
  the stands, moss on the ridge crests, the Taiga's peat basins between —
  the Taiga's own ground (`shape.taiga_feature`), dressed pale and open
  where the Taiga is dark and close. No terms of its own; the cold core's
  cross-fade band is at 980 of 1,024 and could not carry any.
- **Salt Pan**, a third of the Glass Waste ("break up the arid mesa ring
  with at least one more biome"): a dead-flat white crust cracked into
  polygons, brine pools in its hollows (the ocean's brine, by the
  terraced fluid fill), salt pillars, dead snags crusted to the knees, a
  rim of dried mud. It does not add terms; it CAPS them — in the "glass"
  programs the ring's terms are taken under the pan's floor where its
  weight is 1, so the mesa's benches and the badlands' fins are cut to
  the flat, and the cap stands a hundred blocks up where the weight is 0.
  From above only: the ring's cuts below its base are shallow and the pan
  keeps them as low spots, and the lower cap cost fifty operations the
  ring did not have (it touched 1,020; it is 968). It sits on the
  province noise's "b" side past a split of 0.2 — a span's fifth entry
  now — inset from the ring's outer strip, which runs in the "verdant"
  programs at 989. The mesa and the badlands keep their spans; it paints
  over them, their structures keep off it, and their landings do too.
- **New nodes**: `lichen`, `salt`.
- Checked headless on a fresh world: all eight cold and glass biomes
  teleported to and named, the pan's pools wet, nothing refused.
  Programs: alpine 607, rim 723 (was 759 — the alpine's terms are cheaper
  than the Wastes'), all 980, glass 968, verdant 989. **A fresh world is
  needed.**

### The rim: painted to the edge, gone cold, and walled with ice

- **The Hem's outer half had never been painted.** Past about 54 km the
  generator could not prove a chunk inside the body, used its `flank`
  programs, and ran no biome fills: bare placeholder to the edge. Now every
  chunk from 51.3 km out runs the new **"edge" programs**, which carry the
  body's wall themselves (`shape.edge_body`, two knots of it, 42 operations),
  so every fill clips at the wall and the generator paints them whether or
  not its gate can prove them inside (`shape.CLIPPED`). The Hem's inner
  band runs the **"hem"** programs, which fade the mild rings' whole terrain
  out under the tundra's across `HEM_BLEND_U`. Both take the sea suffix;
  their shores take a new **plain shore profile** (`shape.coast_plain`: the
  floor, the face, the terrace and the ledge, no jag, cuts, bars or reef).
  Programs: edge 348, edge_shore 462, hem_shore 759.
- **The rim is the cold rim** ("the world needs to get colder as it nears
  the edge again until an ice wall is hit right at the last couple hundred
  blocks"), three biomes in bands of the wobbled radius:
  - **3.0 Frostpine Coast**, 50.1 to 53.7 km: snowbound fir stands with
    snowfields between, dead firs at the stands' edges, erratics, frozen
    tarns. The fourth lane's sea runs through it.
  - **3.1 Rime Tundra**, to two hundred blocks from the edge: the Hem's
    ground everywhere (`shape.tundra_terms`) — a long roll, hummocks, frost
    polygons, pingos with fallen-in tops, frozen tarns — dressed in
    permafrost, turf mats, gravel troughs and snow whose share climbs from
    a fifth of the ground to nine tenths toward the wall. Erratics and
    frost-heaved slate. A cold haze.
  - **3.2 The Rime Wall**, the last two hundred blocks: drifts climbing
    fifteen blocks, then a face of glacier ice about seventy blocks high,
    ragged along its length and standing twelve to seventy blocks in from
    the edge; a snow top with clear-ice crevasses and ice spires; calved
    blocks in the drifts; a whiteout. Past its top the world ends.
  The Woodlands, Grasslands, Dunes and Flower Forest now stop at the Long
  Shore's edge, and so do the rivers (the "hem" programs lift the trough
  out; the "edge" ones carry none).
- **The edge wanders with the rings.** The body's wall at the surface is
  where the wobbled radius the biomes go by is `shape.EDGE_U`, so the wall
  follows the rim: 57.45 to 59.8 km. **The engine's world is a square
  60,000 blocks either way**, and a rim at the old 59 km wobbled out to
  60.2 along the axes — outside the world, where `/tp rime wall` silently
  did nothing. The flank's own three-dimensional warp still shapes the
  underside, faded in under 14 km of Spindle height, and now only ever
  pulls in: warped outward it bulged to 63 km, past the square.
- **The slack every ring test widens by is a share of the radius**
  (`shape.wobble(u)`), since the wobble itself has been one since the
  axis fix: a fixed 0.010 of u was four times too little at the rim and
  too much at the core. The cold core's modes are cheaper for it (the
  "alpine" programs now reach 8 km).
- `/tp` reaches the rim (it stopped at 52 km), and the three rim biomes
  locate by solving for their band along sixteen bearings: the generic
  search steps across a span in shares of it and never found a band two
  hundred blocks wide. `/tp rime wall` lands in the drifts facing the wall.
  The HUD asks `tdw.rim_at` first. The seas keep inside 57 km.
- No new nodes. Checked headless on fresh worlds: all three named on the
  HUD, the wall's profile measured on an axis and a diagonal, the Hem's
  sea floor clean, and the cold core, Ember Ridge, Glass Waste, Verdant
  Belt and Long Shore toured again with nothing refused. **A fresh world is
  needed.**

### The Ember Ridge broken up: a sea, the Obsidian Barrens, the Geyser Basin, the Cinder Coast

- **A sea lane through the ridge** ("the volcanic foothills needs to be
  broken up with some oceans"), 21.0 to 22.8 km, its outer shore cut by
  the Glass Waste's keep-out. The ridge could not have a shore before:
  its terms and the full coast profile were 1,030 operations. The "ember"
  programs now take the sea suffix with the plain shore profile the rim
  got (`shape.coast_plain`). Programs: ember 824, ember_shore 947.
- **Half the ridge is a second province** ("and a couple more biomes that
  are still vaguely in the same theme"). In the "ember" programs the
  Foothills' terms stand on province "a", and on "b" the dry side's and
  the wet side's own, weighted by a province weight centred on the line
  (`shape.ember_province_a`) so the two always sum to one. The lava pits'
  cap stands a kilometre up on "b".
  - **3.3 Obsidian Barrens**, dry: sheets of black glass laid in lobes with
    steep fronts, razor pressure ridges along a contour, shard fields,
    glass spires, ash and pumice in the lows.
  - **3.4 Geyser Basin**, wet: a shallow basin of pale sinter stepped in
    terrace dams round hot pools (water, by the terraced fluid fill),
    orange thermal mats in the runoff, mud pots, sinter mounds, geyser
    cones with sulfur throats that puff steam by the Foothills' random
    tick, dead snags at the edges.
- **3.5 Cinder Coast**, the lane's shores: black sand beaches and shelf,
  basalt faces glazed with obsidian, lava rock pavements in the shallows,
  sulfur at the tide line, basalt sea stacks and glazed boulders. It
  paints the shore and the shelf, and the Coastal Cliffs keep off the
  ridge (`shape.off_cinder`); `/tp coastal cliffs` skips its lane.
- The Foothills' fills keep twenty blocks off the sea now. The HUD asks the
  Barrens' and the Basin's placement fields before the Foothills'.
  `seas.locate` takes a list of lanes to skip.
- **New nodes**: `obsidian`, `sinter`, `thermal_mat`, `black_sand`.
- Checked headless on fresh worlds: all four teleported to and named (the
  Cinder Coast's landing is inland of its beach, where the HUD reads the
  ground behind it), the Basin's pools wet, the lane's deep water, the
  Coastal Cliffs unchanged on the first lane, nothing refused. **A fresh
  world is needed.**

### The Heather Moor, on three quarters of the Flower Forest's ground

- **3.6 Heather Moor** ("flower forest should be much more rare and to do
  that I want to add another biome that will take up about 75% of what
  flower forest does now"): open heath on the wet side of the mild rings —
  a purple carpet of heather over peaty turf, gorse in yellow-green clumps,
  bracken in patches, granite boulders and tors, strips of bare black peat
  where it has been cut, wind-bent hawthorns alone, and dark water in the
  gullies' deepest reaches.
- **Where**: the Flower Forest's province side, "b", from the line to a
  split of 0.383 of the province noise, and the Flower Forest past it.
  0.383 is the noise's 87.5th percentile, measured over 40,000 samples, so
  the forest keeps an eighth of the wet side where it had a half: a quarter
  of its ground. A span's **sixth entry** is an upper province split.
- A dressing biome: the mild rings' programs are at 999 of 1,024. It
  stands on the wet side's gullies and bluffs and the Flower Forest's
  knolls.
- **New nodes**: `heather`, `gorse`. Bracken is the woodland's fern, peat
  is `black_mud`. The HUD's mild-ring placement fields include it.
- Checked headless on a fresh world, in the temperate ring and on the Long
  Shore: heather 25–40% of the surface, peat 6–19% (a first cut of 28% was
  thinned), gorse, bracken, the gullies' water, named on the HUD; the
  Flower Forest and the Woodlands unchanged; nothing refused.

### Two seas of their own: the Kelp Forest and the Pack Ice

- **3.7 Kelp Forest**, the third lane's water (41.1 to 48.5 km): kelp in
  dense groves over the shelf, in three depth bands whose heights keep the
  tops a few blocks under the surface — to thirty-four blocks tall at the
  ledge's foot — on a floor of sand between moss-grown rock reefs, with
  urchin barrens of bare gravel where the groves open and boulders fallen
  off the ledge. The lane's sea side, to the shelf's end, on the TRUE
  radius (the lanes are placed by it); the Coastal Cliffs keep the land
  side (`shape.off_kelp`), as they do along the reef's lagoon.
- **3.8 Pack Ice**, the fourth lane's surface (49.8 to 57 km), off the cold
  rim: floes two and a half blocks thick with snow drifted on them, open
  leads along a contour, pressure ridges, and icebergs standing sixteen
  blocks over the water and forty under it. The sea's own fill lays it
  before the water (`tdw.pack_ice_into`), because a chunk of sea surface is
  an air chunk to the generator and runs no biome fills. It is laid at the
  level map's height, one operation where the fluid's stepped level is
  three hundred, and so from 130 blocks off every shore and sill, where
  the map ramps between pools.
- The HUD names the pack over the fourth lane's water, deep or not, and
  the kelp over the third's shelf.
- No new nodes. Checked headless on fresh worlds: the kelp forest's floor
  sand 40%, moss-grown rock 37%, barrens 12%, kelp standing; the pack's
  surface 57% ice and 40% open water; both named; nothing refused.

### Two more seas: the Abyssal Trench and the Mangrove Coast

- **3.9 Abyssal Trench**, a province of the deep floors (the province
  noise's "b" side past 0.1, about two fifths of them): rifts a hundred
  and ten blocks either side of a contour and 170 deep, with a slot in
  their floors 200 deeper; along a vent line in them black smoker chimneys
  to twenty blocks, sulfur-crusted with magma glowing in their throats,
  tube worms round their feet, bacterial mats, and glowing polyps over
  the dark mud. The rifts are cut into the Deep Ocean's floor in the
  coast's `shape.sea_deep`, weighted by the province and the shelf's blend
  (deep programs 357, were 323). The Deep Ocean keeps off the province
  (`shape.off_abyss`), and its `/tp` does too.
- **3.10 Mangrove Coast**, the reef lane's wet-side shores, from 24 blocks
  inland to 20 out: mangroves standing on arched prop roots at the tide
  line under a low roof of leaves, saplings in the shallows, mud flats,
  black silt, tidal channels, moss behind. The reef and the Coastal Cliffs
  keep off it (`shape.off_mangrove`).
- `seas.locate` takes an `accept(x, z)` test. The HUD names the trench over
  its province's deep water and the mangroves on their strip.
- **New nodes**: `tube_worms`, `glow_polyp` (it gives light),
  `mangrove_wood`, `mangrove_leaves`.
- Checked headless on a fresh world: the mangroves' strip leaves 25%, mud
  19%, silt and channels; the reef beside it unchanged; the trench landing
  over a rift with its walls, polyps and mats; the Deep Ocean's landing
  off the province; nothing refused. **A fresh world is needed.**

### Four for variety: Savanna, Karst Towers, Peat Fen, Redwood Stands

- **3.11 Savanna** takes the Verdant Belt's dry half from the Rolling
  Grasslands (they keep the temperate ring's and the Long Shore's): golden
  grass to the knee over red-brown earth, flat-topped acacias, termite
  mounds, kopjes of rounded granite, thorn shrubs.
- **3.12 Karst Towers**, a third of the Jungle's ground (its province "b"
  past 0.25): limestone pinnacles to fifty blocks over a forest floor of
  grass, ferns and mud pools under broadleaf trees, moss streaked down the
  walls, scrub on the tops. Its terms stand in the "belt" programs, faded
  in only well inside the belt so no "verdant" chunk (989) needs them.
  Programs: belt 485, belt_shore 994.
- **3.13 Peat Fen**, a quarter of the Temperate Woodlands' province in the
  temperate ring (province "a" under -0.383): sphagnum over black peat,
  dark pools in every gully floor ringed with reeds, cotton grass, bog oak
  stumps and trunks half sunk.
- **3.14 Redwood Stands**, the same share on the Long Shore: redwoods forty
  to sixty blocks on buttressed feet, bare for two thirds of their height,
  younger trees between, ferns over needle mulch and moss, fallen giants.
- The Fen and the Stands are dressing biomes (the mild rings are at 999).
  The HUD's placement fields ask all four first.
- **New nodes**: `golden_grass`, `acacia_wood`, `acacia_leaves`, `reeds`,
  `redwood_log`, `redwood_needles`.
- Checked headless on a fresh world: all four teleported to and named;
  savanna grass 42%, the fen's pools wet with reeds at their edges, the
  redwoods' crowns over 56% of the square; towers measured by the terrain
  field, a sixth of a 480-block square standing 25 to 61 blocks over the
  floor; the Jungle, the Woodlands and the reef unchanged; nothing refused.
  **A fresh world is needed.**

### One of each: the block list consolidated, and colour by biome tint

- **The designer's rule** ("if a biome needs different colored grass or
  lichen or dirt then the per biome tint needs to be changed"): no variant
  blocks. Gloam stone is now **dark sediment** with **light sediment** laid
  in flat beds through it (a noise stretched tenfold in x and z, only in
  chunks wholly of the gloam's rock). Abyss, lantern and dream stone are
  **morphic rock**, **hot fiber stone** and **cold fiber stone**. Loam and
  alpine turf are **dirt**, leaf litter **mulch**, creek bed **gravel**,
  limestone **stone** (the Karst Towers are stone towers now), columnar
  cactus **cactus**, black sand **dark sand**, sinter **lava rock**, thermal
  mat **magma**. Every wood is a **log** (willow, kapok, juniper, apple,
  cherry, mangrove, acacia; dead wood is `dead_log`), as the ironwood was.
- **The grass tufts** (alpine, golden, rust) are the one `tall_grass` tuft,
  not the `grass` block: the turf is a solid block and would have stood up
  out of the ground as a cover. **Hanging lichen** is `lichen`. **Sea
  anemones** were a cover on the reef's drop-off wall, which is calcite
  already: the cover is gone. **Tube worms** are a crust of `barnacles`
  round the trench's vents.
- **Colour by tint**: `tdw.biome_tint(id, rgb, field)` answers a chunk with
  a biome's colour where its mask covers it, half way at its edge. Set for
  the Frozen Wastes, Icefall and Alpine Highlands and the Hem's three
  (cold blue-green), the Taiga (rust), the Silverwood (pale) and the
  Savanna (dry gold). The tint multiplies: it can shift the one grass
  toward gold but not brighten it — engine ask 33.
- **A ring of unpainted sea floor round every shelf**, found on the way:
  the Deep Ocean and the Abyssal Trench painted only chunks wholly past the
  shelf's end, and a chunk across that line was a shore chunk the coast
  paints only to the line. Both now paint any chunk that reaches past it
  (`seas.reaches`).
- The HUD's ownership lost the blocks that are shared now (the alpine's
  turf and tufts no longer name it; the fields and the rest do).
- Checked headless on fresh worlds: the alpine, the Taiga, the Savanna, the
  Geyser Basin, the Abyssal Trench, the reef, the Woodlands, the mesa and
  the Cinder Coast toured, each named and painted with the new blocks; the
  trench's floor mud, polyps and basalt with no soil; every block has its
  texture; nothing refused. **A fresh world is needed** (block ids changed).

### Lava that glows, and peat hags that are not stripes (2026-09-16)

Asked: "lets make lava glow and fix the weird geometric mud stain", with a
screenshot of the Heather Moor crossed by a long, straight-edged band of
black ground.

- **Lava glows.** Engine b6935c3 (engine-asks 31) made a fluid give off the
  light of the block it is drawn as. The mod's `lava` block already emits
  `r15 g8 b1`, so the pits and channels light up with no change to the
  lava itself. The fluid is now declared `opacity = 1.0` too: a surface
  of molten rock, not a window onto the pit's floor. Measured headless
  (engine HEAD b03fa42, seed 12345): a generated lava block reads
  `r15 g8 b1`, and two blocks over its surface still reads `r14`.
  An engine older than b6935c3 refuses `opacity` as an unknown field, which
  disables the whole mod (the Sep 15 `server.exe` did), so the lava is
  registered without it there. Glowing needs a client built from b6935c3
  or later.
- **The mud band was the moor's peat hags.** They were one octave of noise
  drawn out five times along x, so every hag was a ruler-straight band
  about two hundred blocks long, all running east–west, laid over the
  hills and down into the gullies. Now two octaves drawn out twice, with
  a ragged edge (a noise at 1/7, amplitude 0.25) that breaks them into
  irregular patches. Their share stays the same: 19.1% of the field over
  6 km, against the old field's 20.0% (threshold 0.30, was 0.40). Checked
  headless: the old field mapped as long bars, the new one as broken
  patches, and a Heather Moor landing painted heather 32%, grass 23%,
  black mud 6%. The codes program is 3 operations longer.
- **Found on the way, not fixed:** a Volcanic Foothills pit near the
  ember sea lane (21.1 km) has the full pit weight but no bowl, so it
  holds one block of lava where it should hold a pool. That spot's shore
  terrain looks like it overrides the pit's cap. A search for pits deeper
  in the ring (23.3–24.3 km, 6 km either way) found none.
- `stubs/game.lua` brought up to engine HEAD (fluid `opacity`).

### Lava that quenches, pits that hold it, and calmer mountains (2026-09-16)

Asked: "look into the lava issue. also lava needs to create a blocks that
are a mix of lavarock, stone, obsidian, and metal when they come into
contact with each other", and, with a screenshot of the Alpine Highlands
full of floating lumps, rings and hollow bowls: "the blend between biomes
[should be] damped down and smoother rather than crazier".

**Dry lava pits.** A survey of the whole Ember Ridge (seed 12345) found 160
pit sites, and almost all of them sat inside the ember sea lane or within a
few hundred blocks of its shores. There the coast lifts the ground to its
beach plain (`coast_plain`, `max(land, floor)`) and fills the bowl, up to
90 blocks over the lava's level. Every pit less than ~400 blocks inland
was dry and held at most a stray block of lava. Two fixes:
- **Pits keep off the seas.** Their weight fades in from 380 to 460 blocks
  inland (`PIT_INLAND`, from the sea distance map).
- **The Foothills' gates are flat in y.** `seg` and `both` (pits, channels,
  cones, levees, gouges, tuff, fissures) were 3D noise, so a pit's
  footprint at the ground's height was not the one a probe or the lava's
  own mask saw a few hundred blocks up, and a gated term could change shape
  a few blocks up the slope. Stretched a thousand times in y (no ops).
- After: 3 pits on this seed, all holding lava (ground 4 blocks under the
  level). Pits are much rarer than before, because most of the ridge's
  core is the sea lane.

**Lava meets water.** Engine 62608bf now reports a flow blocked by a
DIFFERENT fluid, beside or below, and names it (`event.meets`). The mod's
flow rule (rules.lua) quenches the lava's block when lava meets water or
brine: the fluid is cleared and the block is solid, its 27 cells lava rock
8/20, stone 5/20, obsidian 5/20 and metal 2/20, by a hash of its position.
New block `metal` (docs/blocks.md). Tested headless in built troughs: lava
beside water, water on lava and lava on water all quenched, e.g.
`lava_rock 15, stone 6, obsidian 5, metal 1`. **Needs engine 62608bf**: an
older engine never reports the meeting, so nothing quenches (nothing
breaks either).

**The Alpine Highlands' wild terrain.** The biome blends were not the
cause: every blend is a linear cross-fade whose weights are flat in y. The
cause was 3D noise in the Alpine terms, amplified by the world's 3D relief
(its vertical slope reaches ~0.6 in the frost ring, so a small vertical
wobble in a term moves the surface several times as far):
- **The crack cut** was 27 blocks deep with its segment and area gates 3D
  noise. The cut flickered on and off with height, leaving lids, bridges,
  rings along the contour and hanging shelves. The gates are flat in y now.
- **The crack's wedge** grew without limit above the map's surface. Where
  the relief lifts the real ground a few hundred blocks over the map, a
  crack was a trench up to 90 blocks wide. Clamped at its mouth (+1 op).
- **The steps** (1/18, steep) are flat in y: terraces in plan. **The ridged
  detail** is drawn out six times in y, so it leans a sixth as much.
- **The snow lift's** wander and fleck noises are flat in y, so no loose
  slabs at the snowline.
- Measured headless over the ground in the frost ring (columns with more
  than one surface within 120 blocks of the ground): **Alpine Highlands
  10.3% → 0.0%** (611 columns). After: Taiga 0.2%, Silverwood 0.1%, Frozen
  Wastes 0.6%, Icefall 0.8%. Op counts: alpine 608, rim 724.
- Not changed: the world relief itself is still 3D. Flattening it would
  reshape every ring and put a seam against every chunk already generated.
  With the Alpine terms flat it no longer shows here.

**A fresh world is needed** for the terrain (existing chunks will seam
against new ones in the Alpine Highlands and the Volcanic Foothills).

### The Karst Towers calmed and weathered (2026-09-17)

Asked: "the Karst towers biome needs its noise turned down about 60% and
could use some erosion".

- **The towers**: up to twenty blocks where they stood fifty, and the jitter
  on their tops three blocks where it was eight (both two fifths).
- **The ground under them**: the Karst Towers stand on the Jungle's terms,
  which applied at full strength there: ±9 blocks of undulation, 12-block
  ridges, 16-block ravines, 10-block sinkholes. Inside the Karst Towers'
  province they are now multiplied by 0.4 (`shape.karst_damp`, on the
  province weight, in both the "belt" and "verdant" programs so the chunk
  boundary between them agrees).
- **Flat in y**: the towers' noises, and the Jungle's sinkhole and hummock
  noises, were 3D, so their footprint changed with height and left hanging
  slabs and lips. All flat now. **This also changes the Jungle**: its
  sinkholes and hummocks sit in new places and no longer overhang.
- **Erosion**: the walls slope (edge 16 → 7, about 55° where they were
  sheer), a fine noise (1/7) weathers the towers' outline, and a skirt of
  gravel scree lies round each foot. The scree is a material only: raising
  it too cost 15 operations the belt's shore programs did not have.
- Measured headless (seed 12345, 603 columns over the Karst Towers' ground):
  columns with more than one surface **9.0% → 0.7%**, mean local rise
  18.3 → 13.8 blocks (hills included). The towers stand on 14% of the
  ground and reach 21.6 blocks. Ops: belt 485 → 500, belt_shore 994 → 1,009,
  verdant 989 → 1,001 (cap 1,024).

### Cliffs brought down to size, and banded (2026-09-17)

Asked, with a screenshot of a grey wall behind a mangrove forest: "a cliff
that looks awful ... about 4x too tall. It also needs to have its noise
stretched out on the vertical axis and have some more natural looking
material distribution." Two water glitches were reported with it (below).

**Why the cliffs were so tall.** At a shore the land was lifted to a beach
floor if it stood lower, but nothing held it down if it stood higher. The
world's relief puts hills hundreds of blocks over a pool, and the coast met
the sea as a face as tall as the hill. Measured over 2,019 shore points
(8–30 blocks inland): median 1 block, 90th percentile 112, **21.2% over 60
blocks**, the tallest 205.

- **A ceiling at every shore** (`seas.CLIFF_H` and after): land stands at
  most 40 blocks over the level for 60 blocks inland, and the ceiling rises
  one block in two past that, so a hill comes down to the sea as a slope.
  A flat-in-y noise (±5 blocks at 1/60) roughens the ceiling, so a hill cut
  down to it is not a plane.
- **The floor and the ceiling are maps** (`sea_floor`, `sea_ceiling`, built
  in the world pre-pass from the distance and level maps), so the shore
  programs read one op for each where the floor alone was fourteen. The
  shore programs got **cheaper**: temperate_shore 999 → 991, belt_shore
  1,009 → 1,001, ember_shore 947 → 946, hem_shore 759 → 751, edge_shore
  462 → 454.
- After: 90th percentile 41, 0% over 60, tallest 54.
- **The faces.** The Coastal Cliffs' faces are their horizontal strata
  (stone, dark basalt, slate), which reach 40 blocks over the sea and now
  cover a face whole. The Mangrove Coast's faces were moss and mud laid in
  blotches over bare stone by a 3D noise (a face in the reef lane measured
  46% stone and 16% moss). Over 10 blocks above the sea it now takes the
  cliffs' strata (`shape.coast_strata_code`), and its silt noise is drawn
  out six times in y. After, the same kind of face measured as trees and
  ferns with 5% stone and 3% mud showing.

**The water walls** (a curved wall of water along a river valley in the
Heather Moor, and water in a moor gully). Not changed: probed headless at
five places where the moor's brooks lie inside a river valley, and in River
Valleys landings, and no water stood more than one block tall against open
air anywhere. The generator is not laying the walls at those places. The
engine has a report of walls of water in an ocean under investigation,
which may be the same thing. Coordinates of a wall would settle it. Noted
on the way: the brook fills of the Heather Moor, Flower Forest and Peat Fen
keep 21 blocks off a river (its bar), not its 150-block valley.

### Performance pass: the body from the layers in shared chunks (2026-09-17)

Asked: "lets do a performance pass. just check and see if we can speed any
of the stuff we already have up."

**Measured** headless with generation on the tick (`TIAMOT_GEN_THREADS=0`),
touring fixed coordinates, timing the generator's own 1,024-chunk counters:
about 120 ms per surface chunk (114.6, 123.4 and 124.0 over three runs of
the old code). A surface chunk ran, on average, 3.85 biomes' layered fills
(each a full terrain evaluation), 6.2 covers and 13.4 structure scatters.

**The body by layers was dead code.** The generator lays a chunk's body
(soil, then stone) from a biome's layered fill with the engine's wildcard
layer, saving two of the terrain evaluations, but only where the chunk
held ONE biome, and the gate lists several nearly everywhere: **0 of 4,038**
surface chunks took it. The body is the chunk's, not a biome's, so it now
comes from the first ground-painting fill in the chunk whenever that is a
body-capable layered fill (and no deep band shares the chunk), run before
every other biome's paint so the order the biomes paint in is unchanged.
Taken by 1,656 of 3,015 surface chunks in the same tour. **About 10%
faster** per surface chunk (107.6 and 109.7 ms).

**Checked against the old generator** by hashing every block within 32 of
nine fixed points on fresh worlds. Seven match exactly, including after a
repeat of the old code. At the Temperate Woodlands and Heather Moor points
237 blocks of 12,675 differ, all at material seams inside a block: the
dirt-to-stone seam five blocks down is drawn a block at a time by the
layered fill where the separate stone fill drew it by cell, and a few
surface blocks lose a stray dirt cell (and the tall grass on them moves by
a cell). The ground's shape is identical.

**What would help most is in the engine** (engine-asks 34): most of those
3.85 layered fills paint nothing (the biome's mask is zero across the
chunk) but evaluate the whole terrain before their code field.

### Hand-made textures (2026-09-17)

The designer's own textures for the leaves (acacia, apple, birch, cherry,
cherry blossom, ironwood, kapok, mangrove, oak, willow), `dirt`,
`packed_dirt` and `stone`, and in a second batch `barnacles`, `bone`,
`calcite`, `charcoal`, `dark_basalt`, `dark_sand`, `dead_log`, `dried_mud`,
`fir_needles`, `granite`, `grass`, `gravel`, `light_sediment`,
`morphic_rock`, `mud`, `permafrost`, `pumice` and `sand`: 16×16 pictures
where each was one flat colour from `tools/make_textures.py`. Running that script again would overwrite
them with flat colours.

### Non-leaf textures back to flat colours (2026-09-17)

Asked: "lets put all the non leaf textures back to what they were". The
hand-made textures stay for the leaves (acacia, apple, birch, cherry,
cherry blossom, ironwood, kapok, mangrove, oak, willow) and the fir
needles. Back to their generated flat colour: barnacles, bone, calcite,
charcoal, dark basalt, dark sand, dead log, dirt, dried mud, granite,
grass, gravel, light sediment, morphic rock, mud, packed dirt, permafrost,
pumice, sand, stone.

### Giant redwoods, earth round the kapoks, a flatter Salt Pan (2026-09-17)

Asked: "random clumps of dirt at the roots of the giant kapok trees so that
when it spawns on a hillside it does not look super strange with roots
sticking out", "salt pan can be a little flatter", and "the redwood trees
need to be about 3 times that big around and about 4.5 times that tall.
with more needles".

- **Redwoods.** Giants 180–270 blocks tall (40–60) with trunks 4.8–7 blocks
  in radius (1.6–2.35); the young trees 81–126 tall (18–28), radius 2.4–3.3.
  Five to seven buttress roots on a giant. More needles: the crown's tiers
  are thicker and wider (up to 13 blocks out), each on a ring of limbs with
  a clump of needles at every limb's end, and a taller spire. The fallen
  giants grew to match (40–60 long, radius 3.2–4.4). The squares they stand
  in widened so trunks don't merge (giants 14 → 36, young 8 → 18, fallen
  48 → 60), and the generator stamps structures up to 300 blocks over the
  ground (was 80). Measured headless: trunks 16 blocks across, tops 283
  blocks over the ground.
- **Kapok roots.** Every kapok template has earth heaped round its foot: a
  low mound under the trunk, a clump over each root's knee and two or three
  more at random round the base, all dirt under the wood's priority, so the
  roots still break through. Checked headless: dirt round kapok feet, most of
  it under ferns and grass.
- **Salt Pan.** The pan capped the ring's terms at its floor, but the
  world's relief came after the cap and tilted the pan. Half the relief is
  taken out on the pan (`shape.SALT_RELIEF_DAMP`), and the crust's ripple
  is a third of what it was. Over 500 columns: height range across 1.2 km
  60 → 47 blocks, mean step over three blocks 0.47 → 0.41. The glass
  programs 968 → 1,005 ops. (Damping the fine hills instead measured no
  flatter and was not kept.)
- **The Silverwood "broken spawn"**: the screenshot did not come through;
  not looked at yet.

### Exports for Weather, and the body ride (2026-09-17)

**The Spindle exports version 1 of Weather's contract** (`exports.lua`,
engine `game.export`): `humidity` (the compiled field, no dither),
`HUMIDITY_SPLIT`, `climate(x, z)` — the ring temperature T = 4t(1 - t),
0 at the axis and the rim, 1 half way out, its square root by the same
twenty-step Newton that Weather's mirror runs so both answer the same bits
— `biome_under(x, y, z)`, and the two unlocks:

- `add_soil_alias(block, dry)` keeps both names as STRINGS and resolves
  them to ids on first use, since the damp blocks register after this mod
  loads. The alias then applies in `tdw.soil_under` (so the grass and rose
  growth ticks count damp dirt as dirt) and in the HUD's owner table.
- `add_harmless_fluid(fluid)` marks a fluid the leaves rule leaves alone
  and the lava rule does not quench against.

An exported function runs in THIS mod's sandbox, and an error in one would
disable the whole world, so each checks its arguments and answers nil or
false. Checked against the weather mod on engine 92267e7: "humidity
exported, warmth exported, biomes exported; damp ground on, puddles on".

**Engine ask 34 landed** (engine 92267e7): a layered fill evaluates the
terrain only where a block's code matches one of that call's layers. On the
same tour as the performance pass, **109.7 → 69.3 ms per surface chunk**.

**The body rides, or takes its own call.** The engine's note says a
`code = -1` band forces its call's terrain evaluation, so the body's two
bands should not sit in a biome's call. Measured both ways: a call of their
own for every surface chunk was **75.7 ms**, riding in the first painting
fill **69.3**, and riding where it can with its own call only where it
cannot **68.4** — riding is free, because that call pays for the terrain
anyway. The generator now does the last of those. Where a deep band shares
the chunk, the old body and stone fills still run.

Over the whole pass: **124 → 68.4 ms per surface chunk**, and block hashes
at nine fixed points match the committed generator except where lava
quenching or settling water makes a point vary between runs anyway.

### The shore's bank, less of a ramp (2026-09-17)

Asked, of the new cliff ceiling: "the ramp bank at costal cliffs looks a
little too smooth. I like the little mini cliff ridge but the rest is kind
weirdly ramp like". The ceiling rose one block in two for nine hundred
blocks inland, and where a hill was cut down to it the ground WAS the
ceiling: a plane, which in blocks is a staircase of wide terraces.

- **The climb is twice as steep**: `CLIFF_FADE` 900 → 450 blocks, so the
  ceiling passes over the land quickly and clips much less of it. Cut
  columns 100–250 blocks inland fell from 35 in a sample to 7, and 250–500
  from 32 to none.
- **The ceiling wanders along the coast**: a slow noise in the map itself
  (`CLIFF_WANDER`, ±15 blocks at 1/900), so one headland is low and the
  next a high bluff.
- **Rougher where it still cuts**: the single 6-block ripple is a shoulder
  noise of nine blocks and a crag noise of three. Cut ground steps 2.70
  blocks per four where it stepped 1.72.
- Cliff heights over 1,200 shore samples: median 1, p90 44, p99 62, max 69,
  none over 80 (before the ceiling: p90 112, max 205).

### The shore programs' budget, and a cap that gives (2026-09-17)

Asked: "lets work on that shore terrain program and find the op budget if
we can". Measured first, by compiling each piece on its own at load:

| piece | ops |
|---|---|
| the ring's own land terms (temperate) | 490 |
| `coast_shore` | 496 |
| — the shelf (`seabed`) | 128 |
| — the notch and sea caves | 62 |
| — the jag | 59 |
| — the tunnels and blowholes | 47 |
| — the face weight, spent TWICE in the cross-fade | 42 |
| — the shore's distance, each use | 9 |

**Fifty operations freed**, `coast_shore` 496 → 446, so temperate_shore is
944 of 1,024 and belt_shore 954 (they were 994 and 1,004):

- **The land/sea gate reads the map's distance**, not the distance with the
  shore's fine detail. It is two blocks wide against a coastline the detail
  moves by thirty, and the face it multiplies carries that detail itself —
  and `coast_shore` spends that weight twice, so this is 14 operations.
- **The jag's outer gate** likewise, nine blocks inland: 6 operations.
- **A height band in one evaluation.** The sea caves and the tunnels each
  asked "above LO" and "below HI", reading the height over the sea twice;
  `half - |h - mid|` reads it once. 20 operations.

**A cap that gives.** A hard cap shears a hill to a surface of its own,
which reads as a ramp however it is roughened ("the rest is kind weirdly
ramp like"). Softening it inside the program needs the land's height twice
— five hundred operations, which is engine-asks 30 — so it is done in the
ceiling MAP, which costs the programs nothing: the ceiling now carries
`CLIFF_SOFT` (0.35) of however far the world's relief stands over it, so
cut ground keeps the hill's broad shape. Cliffs over 1,200 shore samples:
median 1, p90 49, p99 81, max 99, 1.1% over 80 (before the soft cap: p90
44, max 69; before any ceiling: p90 112, max 205). Lower `CLIFF_SOFT` for
shorter cliffs, raise it to keep more of the hill.

### The ores (2026-09-17)

Asked, as preparation for the caves: "add a basic list of ores and
distribute them at various depths below the world ... scatter these things
in veins or clusters as subnodes within full blocks of whatever, very
rarely should there ever be a full block of diamond though simpler
materials can more often be full blocks. Each one should appear from its
level downward."

- **Eleven new blocks** (docs/blocks.md): copper, iron and flint from the
  surface; coal and the pan's `salt` from 100 blocks; tin and silver from
  350; chromium and lead from 700; gold from 1,200; diamond from 2,000 (the
  Gloam); orichalcum, faintly lit, from 3,500.
- **How they lie** (generate.lua, `ORES`): a field per ore — the smooth
  depth past the ore's level, so a chunk above it is skipped for nothing,
  and a vein noise over a threshold — laid by a smooth `fill_density`, which
  samples per block and carries the edge to the cells. A vein is whole
  blocks in its middle and cells in the rock round it; the finer the noise
  the smaller the vein and the rarer a whole block. Seams and lodes are the
  noise drawn out along an axis. The engine's noise sits at its clamp an
  eighth of the time, so a single noise cannot be rare: every ore is where
  two independent noises are both over their threshold, the gold, diamond
  and orichalcum where three are.
- **Only in rock that is solid throughout** (`tmin > 0`), so no ore stands
  in air or in a biome's soil; they begin a chunk under the ground and are
  overwritten by the core stack where it reaches.
- **Measured** (eight 12-block cubes per ore, half a kilometre under its
  level): coal 2.8% of the rock and a third of that whole (seams), iron
  1.9%, tin 1.7%, copper 1.3%, lead 1.3%, silver 1.2%, salt 1.2% (a quarter
  whole), chromium 0.9%, flint 0.8%, gold 0.6%, diamond 0.2%, orichalcum
  0.2% — and not one whole block of diamond or orichalcum. Before the lode
  gate every ore was three to seven per cent.
- `tools/make_textures.py` now keeps the hand-made textures (`HAND_MADE`)
  and only writes the flat ones.

### The ores, shallower (2026-09-18)

"redistribute so the lowest ore is at 2000 blocks with diamond being at
1200": copper, iron, flint from the surface; coal and salt from 60 blocks;
tin and silver 200; chromium and lead 420; gold 750; diamond 1,200;
orichalcum 2,000. The same proportions, scaled to the new bottom.

### The normal caves: Mossy Limestone, Crystal Seam, Underground River (2026-09-18)

The first three cave biomes, from the designer's briefs, under the rule of
**one new material and one new plant a biome at most**.

**The framework** (`biomes/caves.lua`). The normal caves' band is 100 to
1,600 blocks under the base dome, its top pushed 120 blocks under the
smooth ground where the relief sinks it, and a cave is carved only in
chunks that are rock throughout, so none opens into a biome's soil. A
slow noise flat in y is the caves' province; each biome takes a band of
it, so the caves change kind every few hundred blocks across. A chunk
asks once which biome it is and runs that biome's fills alone: a carve
(air where a field is positive), linings by a layered fill whose depth is
the void's negative, covers on the floors, structures rooted on floors —
or on ceilings, with the field negated, since the engine's `scatter`
stamps at any rock-over-air crossing — and pools and rivers by the
terraced fluid fill. Between two biomes is a wall of rock. The HUD names
the cave a player stands in (`tdw.cave_under`), and `/tp <cave biome>`
drops them into the nearest of its voids.

- **2.1 Mossy Limestone**: two storeys of vaulted domes (a footprint noise
  cut by a vertical profile, the footprint shrinking a block per block
  toward floor and ceiling, scooped by a fine noise) joined by three-block
  crawlspaces along contour lines at the storeys' floors. Calcite walls,
  mud floors with gravel beds and calcite rimstone basins holding still
  water, moss over half the floors, ivy hanging from the ceiling's
  crevices, maidenhair at the drips, calcite boulders. **New: `maidenhair`.**
- **2.2 Crystal Seam**: fault corridors along contour lines, four to eight
  wide at the floor narrowing to a quarter of that at the ceiling twelve to
  twenty up — the cleft; geodes, blobs of a fine noise within three blocks
  of the fault, hollowed and lined. Slate over basalt, planar crystal veins
  (a noise drawn out six times along the ground), crystal knobs sampled to
  the cells in the last block of rock before the void, shards on the
  floor, spires at the pinch-points, clusters on floors and hanging from
  ceilings. **New: `crystal`**, translucent and faintly lit.
- **2.3 Underground River**: meandering tubes along a two-octave contour,
  ten to eighteen wide, six to ten high, an undercut outer bank and a
  sloping inner shelf (the bend's inner side, from the signed contour and
  a bend noise, rises past the channel's edge); a channel 2.6 blocks deep
  of water down the middle, over cobbles and gravel; silt flats on the
  banks, moss pads in the current, glowing algae at the waterline,
  bleached roots from the ceiling, snags at the choke points. **New:
  `cobbles`, `glow_algae`.**
- **Checked headless** on all three: the voids, the linings, the covers
  and the structures where the briefs put them; the river's channel and
  the basins holding water; the HUD naming each; `/tp` landing in each.
- **`white_unbuilt` is off.** The dev switch painted everything under the
  surface band as the white placeholder, and the ores and the caves keep
  out of a placeholder world — so neither had ever generated in a chunk.
  The ores had only been measured as fields. Now that the underground is
  being built, the switch is off.
- **The caves are carved after the sea's fill**, which floods every open
  space under the sea's level inside its area: carved first, a cave under a
  sea would be flooded a hundred blocks under its floor. (The next day's
  entry corrects the reason first given.)
- **Three traps, written down** (engine-asks 35 for the first): a terraced
  fluid fill reads `level` and `within` on the slice at world y = 0.5, not
  the chunk's floor, so those fields must read no y at all; the bot has no
  physics, so a bot dropped into a void hangs where it was put; a program
  that reads the void twice runs out of the eight buffers, so `-1.2 < v
  < 0` is written `0.6 - |v + 0.6|`.
- Not measured: the cost of a cave chunk. Its fields are 270 to 590
  operations and a chunk runs seven or eight fills; the tour generated its
  chunks fast enough that a bot's view filled in a minute.

### Walls of water at the coasts (2026-09-18)

Asked: "there are chunk walls in large bodies of water and my engine cannot
find it ... Could you check and see if you can find out why". Measured
headless: every water block near a landing, checked for a sideways face open
to air, on chunk seams and inside chunks.

- **The open sea was already seamless**: Deep Ocean, the reef, Kelp Forest
  and Pack Ice, about 363,000 water blocks, no open face anywhere.
- **The coasts were not.** The coast's terrain rises from the sea floor to
  the land on the LAND side of the shoreline (the face, four blocks; a
  beach, thirty-four; the notch, sea caves and tunnels cut inland of it),
  and the sea's water stopped at the line, so all of that lay dry under the
  sea's level and the sea stood against it. One 81x81 patch of the reef
  lane's coast: 144 open faces on seams, 84 inside chunks, up to 16 blocks
  tall; the Mangrove Coast 49. **The sea's water now reaches 80 blocks past
  the shoreline** (`seas.WATER_INLAND`), where there is room under its
  level — which is only the ramp and the cuts; dry land is untouched.
- **River valleys near a sea were cut 30 blocks under it.** The coast lifts
  the land near a shore to a plain at the water's height, but the valley
  was cut from the land under the plain, 50 to 120 blocks from the sea,
  where the river's own water is off. With the water reaching inland, the
  sea stood against the trench: a wall 31 blocks tall. **In the shore
  programs the valley is now cut from the coast's beach floor** where that
  stands higher (`shape.river_valley(floor)`, two ops: temperate_shore 946,
  belt_shore 956), so a river reaches the coast as a plain at the water's
  height and still cuts as deep as it likes inland.
- After: zero open faces at both coasts measured, and across the seas
  again; lakes keep only the one- and two-block edges of shorelines.
- **What is left looks like the client's** (engine-asks 36): water beside a
  chunk that has not arrived is meshed against air (`ABSENT_POLICY`), a
  chunk-wide sheet of water at the streaming frontier.
- Corrected: the caves run after the sea because the sea's fill floods
  every open space under its level inside its area, not because a terraced
  fill empties columns outside its `within` (it leaves them alone).

### More caves, their mouths, and the surface kept to the surface (2026-09-18)

The designer: "lets be sure that surface biomes dont really extend down
into the ground too far. The caves seem just a little sparse to me. lets
add a few more and lets be sure they sometimes come to the surface so you
can stumble across one."

- **Denser caves.** Mossy Limestone has a third storey of rooms (0.74 km
  down, between the two) and a lower room threshold (`ROOM_MIN` 0.06 to
  0.03). Crystal Seam has a second level of corridors at 1.25 km on its own
  fault and floor streams, and closer fault planes (1/160 to 1/100).
  Underground River has a second river at 0.42 km on its own course, with
  its own terraced water fill, and closer meanders (1/420 to 1/260). The
  first level, storey and river stay where they were. Measured over 160
  columns per biome, the share of columns that meet a cave and the void
  per column:

  | biome | before | after |
  |---|---|---|
  | Crystal Seam | 11 %, 1.4 blocks | 41 %, 5.5 blocks |
  | Mossy Limestone | 60 %, 7.3 blocks | 69 %, 11.4 blocks |
  | Underground River | 7 %, 0.6 blocks | 18 %, 1.6 blocks |

- **Cave mouths** (`caves.lua`, "the mouths"). A mouth is a tunnel five
  wide and five tall that winds along a contour line. Its depth under the
  smooth ground follows a slow noise, from 40 blocks above the ground down
  to 500 blocks. Where it crosses the real ground it opens as a slit or a
  hole, then runs down toward the cave band. Mouths appear only in mouth
  zones, which cover about half the land, and never within 150 blocks of
  the sea or inside river valleys, because water would pour in and stand
  as a wall where its fill ends. The tunnel is carved in surface chunks
  after the biome's paint, plants and trees, and in the rock chunks below.
  The first cut sat about 400 blocks down almost everywhere, which gave
  0.25 openings per km². The depth now centres at 80 blocks, with a wider,
  gentler noise. Over three 6 km squares, a 24-block grid finds
  0.4 to 1.8 openings per km². The grid misses most of a five-wide slit,
  so the real count is higher.
- **The surface biomes stay at the surface.** The HUD now names the depth
  band ("Normal Caves" and the bands below it) anywhere more than 40 blocks
  under the smooth ground, instead of the surface biome above
  (`tdw.depth_area_under`, `whereami.lua`). A cave biome's own ground still
  names its cave biome. The deepest bands of the biomes that painted far
  down were cut back:

  | biome | depth, before → after |
  |---|---|
  | Deep Ocean | 400 → 370 |
  | Abyssal Trench | 500 → 390 |
  | Rime Wall | 120 → 92 |
  | Karst Towers | 80 → 30 |
  | Frozen Wastes | 40/45 → 24 |
  | Icefall | 40 → 24 |
  | Kelp Forest | 40 → 12 |
  | Dunes | 30 → 20 |

### Smaller redwoods; the Taiga's water taken off its hillsides (2026-09-18)

- **Redwoods at 60%** ("reduce the size of the redwoods to 60% of what they
  are"). `SIZE = 0.6` in `redwood_stands.lua` scales every length in a
  tree: height (giants 108 to 162 blocks, young trees 48 to 75), girth,
  buttresses, the crown's tiers and limbs, the spire, and the fallen
  trunks. The spacing shrinks with it (giant cells 36 to 22, young 18 to
  11, fallen 60 to 36), so a stand is as dense as before. The crown's
  tiers are three blocks apart instead of four, so a smaller tree keeps as
  many.
- **No standing water in the Taiga** ("aggressive, weird water blobs all
  over the hillsides, covering the trees"). The Taiga's pools were a fluid
  fill whose level was the basin floor over the world's relief. The Taiga
  runs from the Ice Cap's edge to u = 0.032, where the relief is 30 to 80%
  of full strength and slopes a third of a block to over a block per
  block. A level that follows that slope is a sheet of water down a
  hillside: at one spot the surface fell six blocks in four columns and
  stood five deep, through the spruce. There were two more faults:
  - Pools were allowed where the Taiga's weight exceeded 0.97, and 3% of
    the Frostmoor's mountains is tens of blocks.
  - The engine reads a fluid's `within` at y = 0.5 (engine-asks 35), and
    the basin noise is 3D, so the pools were cut out of the wrong places.

  Nothing in a density program can find where the relief is level, and
  lips would only turn the sheets into stairs. So the fill is gone. The
  basins keep their black mud, peat and moss. Measured after the change
  at seven Taiga spots of 128 × 128 blocks: no water. The Alpine lakes,
  which flatten their own ground through the maps, are the frost ring's
  water.
- **The HUD's depth check reads the relief at the player's height.** The
  first cut read it at y = 0.5, where the 3D relief noise is another hill,
  up to 500 blocks off near the Ice Cap. It named Taiga hillsides "Normal
  Caves".
- **The mouth count, measured again** with the smooth ground solved at its
  own height (the earlier probe made the same y = 0.5 mistake): 0.2 to 0.7
  openings per km² on the 24-block grid over three 6 km squares, against
  0.4 to 1.8 before. The samples are small; the order holds.

### Brooks that stay in their gullies, water that breaks grass, crystal veins, moss cushions (2026-09-18)

- **The brooks no longer pour out over the meadows** ("water running
  across a cherry tree field ... originating from a little cubby hole").
  The Flower Forest's brooks, the Heather Moor's brooks and the Peat Fen's
  pools set their water level from the SMOOTH ground (relief, dome, knolls)
  less most of the gully's depth. The real ground also carries the world's
  detail (±3 blocks) and the bluffs' steps (±1). So where a gully ran
  through a dip in the detail, its bank stood under the water, and the
  brook spilled out of the gully's end and ran across the grass.
  `shape.gully_water_level(at)` now puts the level `at` of the gully's
  depth under the ground as it would stand without the gully: the terrain
  program of the fill's own mode, plus the gully's cut. The engine solves
  a fluid level at its own height, which is what lets a level ride the
  terrain. The bank is always over the water. Measured at eight Flower
  Forest spots: 17 wet columns outside the brooks at one spot before the
  change, none at any spot after.
- **Running water breaks grass** ("Grass should probably get broken by
  water"). Every block a body walks through (`passable`: grass, ferns,
  flowers, reeds, mint and the rest) is listed in `tdw.washes_away`. Where
  water is moving, the plants in its path go and the water stays
  (`rules.lua`). The engine gives no direct way to do this, so the rule
  works round two gaps:
  - A tuft is too few cells to stop water, so no report ever names a
    plant.
  - The fluid hook cannot read the world: every `get_block` in it came
    back nil.

  So the hook notes where water was stopped, and on the next tick the
  rule sweeps 7 × 7 blocks around each of those places for a plant with
  water in it. Measured with a flood poured on a meadow: the 20 plants in
  water went, the 82 dry ones stayed, and the mod's share of a tick peaked
  at 1.4 ms. Engine-asks 37 asks for the direct way.
- **Crystal veins, and less crystal lying about** ("reduce the amount of
  random Crystal and Crystal seams. Rather let's have veins of it running
  through the rock around and also through the caves").
  - The Crystal Seam's share of the caves' provinces fell from 37% to 18%
    (its edge moved from -0.12 to -0.30, and Mossy Limestone takes the
    difference).
  - Its lining's short vein blobs are gone. Its knobs, shards, clusters
    and spires are a third to a half of what they were.
  - Every cave biome now lays **crystal veins** (`caves.vein_node`): tubes
    a block or two thick, one wherever two flattened noises cross zero
    together, running along the rock for tens of blocks. Each cave biome
    lays them after its lining and outside its own void, so a vein runs
    on through the rock and shows on every wall, floor and ceiling a cave
    cuts through it.
  - Measured through the cave band: veins are 0.93% of the Seam's rock
    (a finer vein noise there) and about 0.3% of the other caves' rock.
    Near a Seam corridor, 75 crystal blocks were on show.
- **Moss cushions on the cave floors, and moss soft light green** ("Moss
  should not be on cards it should be a decoration like thin bushes except
  soft light green"). The Mossy Limestone floor's moss was a one-cell
  cover, which read as flat cards on the mud. Where it was, a scatter of
  cushions now stands instead: three to six rough lumps each, a block or
  two across and half a block to a block high. Measured in one room: 91
  moss blocks, all partly filled, 60 of them two cells or more high. The
  `moss` texture is now soft light green, 142, 178, 104, where it had been
  the rainforest's deep 70, 102, 54. The mod keeps one moss block (no
  variants), so all moss changed colour: the Jungle's floors, the Taiga's
  hummocks, the mossed logs and stones.
- **Engine asks moved** to the engine repo, `docs/engine-asks/
  tiamot_default_world.md` (engine ae7d45b), beside the other mods' asks,
  where the engine agent reads them. `docs/engine-asks.md` is the history
  now. Ask 35 is marked half landed: the level is solved at its own
  height, but `within` is still read at y = 0.5.

### Housekeeping

- `stubs/game.lua` and `AGENTS.md` re-vendored from the engine's `api/`.
- `docs/engine-asks.md`: landed today in the engine — 9 (crossed cards),
  10 (a per-biome hue, as `game.register_chunk_tint`, engine 33dd9df, not
  yet used here), 12 (noise bounds over a box) and 15 (the cover fill),
  both in engine ffac6e0, which also carries the fix for 14. Items 13 and
  14 record the two sprite bugs; 16 and 17 are open.
- Everything in this entry was verified headless: engine unit tests, the
  mod check in both the dev and real-world modes, and a scratch server with
  scripted bots generating chunks, picking a rose bush, and landing on the
  alpine plateaus. Nothing was looked at in a window after the first grass
  screenshot of the morning.
