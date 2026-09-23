-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- 2.2 Crystal Seam (2026-09-18).
--
-- Narrow fault corridors four to eight blocks wide and twelve to twenty
-- tall, their ceilings V-shaped clefts; dark brittle host rock cut by
-- planar mineral veins; hexagonal crystal clusters jutting from the walls,
-- spires floor to ceiling at the pinch-points, geodes hollowed into the
-- wall face, shards on the floor.
--
-- THE CORRIDORS follow contour lines of a slow noise (the shear planes).
-- A corridor's floor is at a depth that wanders slowly; above it the
-- corridor is W wide at the floor and a quarter of that at the ceiling,
-- H up — the cleft. Geodes are small blobs of a fine noise within reach of
-- a wall, hollowed and lined.
--
-- Materials: the host rock is `slate` (dark, splits in sheets) over
-- `dark_basalt`; **one new material, `crystal`**, translucent and faintly
-- lit; no plant.
--
-- **The variant: Fractured Amethyst Seam** (2026-09-23, "one decoration
-- variant of each of the cave biomes", and no new blocks). The same
-- corridors redressed, split by the caves' variant noise (caves.lua). The
-- spires and the prism clusters keep to the base side; on the other, the
-- floors hold sunken geode pockets — a dark rind hollowed open at the top,
-- its bowl lined with ragged glowing druse and a smoky fleck of obsidian
-- ("concave, hollowed-out geode pockets... glowing with deep violet and
-- smoky quartz druse"; the crystal's own blue-violet light is the violet
-- we have) — the scree is mixed into a bed of fine gravel with bare
-- crystal glinting through it, and the ceiling clefts hang needle-thin
-- crystal chandeliers where the base dressing's chunky hangers would be.
-- The brief's prismatic bursts of scattered player light are a runtime
-- effect and out of this round's scope: the glint patches and the druse
-- carry `crystal`'s steady light instead.

local blocks = tdw.blocks
local shape = tdw.shape
local schem = tdw.schem
local n = shape.node
local ID = "crystal_seam"

-- Two levels of corridors since 2026-09-18 ("a little sparse": a column
-- through the Seam met a corridor 11% of the time), and the shear planes
-- closer together. Level 1 keeps its streams, so the first level's
-- corridors stay where they were; level 2 has its own.
local LEVELS = {
    { floor = 0.75, wander = 0.45, fault = "cs_fault", floor_stream = "cs_floor" },
    { floor = 1.25, wander = 0.25, fault = "cs_fault2", floor_stream = "cs_floor2" },
}
local FAULT_FREQ = 1 / 100                              -- the shear planes (1/160 until 2026-09-18)
local WIDTH, WIDTH_VARY = 3.0, 1.0                      -- half-width at the floor: 4 to 8 across
local TALL, TALL_VARY = 16.0, 4.0                       -- blocks: 12 to 20
local NARROW = 0.75                                     -- the cleft: the half-width lost by the ceiling
local GEODE_FREQ, GEODE_MIN, GEODE_R = 1 / 5, 0.40, 3.0 -- geodes: fine noise blobs, this many blocks into the wall
-- Less crystal lying about, and veins of it instead (2026-09-18: "reduce
-- the amount of random Crystal and Crystal seams. Rather let's have veins
-- of it running through the rock around and also through the caves"). The
-- lining's short vein-blobs are gone, the knobs, shards, clusters and
-- spires are a third to a half of what they were, and the rock is laced
-- with the caves' crystal veins (caves.lua, `vein_fill`), which every cave
-- biome carries and this one most of all.
local VEIN_ZONE, VEIN_FREQ = -0.30, 1 / 30             -- the veins' fields cover nearly all this rock, and closer (the others': 0.0, 1/48)
local CLUSTER_FREQ, CLUSTER_MIN = 1 / 2.2, 0.45         -- crystal clusters jutting from the walls (0.38 until 2026-09-18)
local SHARD_FREQ, SHARD_MIN = 1.4, 0.47                 -- shards on the floor (0.40)
local SPIRE_CELL, SPIRE_SQUARES = 9, 0.12               -- (0.30)
local CLUSTER_CELL, CLUSTER_SQUARES = 5, 0.15           -- (0.40)
-- The Fractured Amethyst Seam's own numbers. New streams are prefixed
-- `fa_`; where a variant field reads a `cs_` stream instead, that is on
-- purpose — the floors and the crowded ceilings are the CORRIDORS'
-- features, and the corridors do not move when the dressing does.
local FA_FLOOR = 1.6                                    -- blocks over a corridor floor the gravel bed reaches
local FA_GLINT_FREQ, FA_GLINT_MIN = 1.6, 0.30           -- bare crystal glinting through the bed
local FA_POCKET_FREQ, FA_POCKET_MIN = 1 / 8, 0.0        -- which stretches of floor hold pockets
local FA_POCKET_CELL, FA_POCKET_SQUARES = 6, 0.30       -- the pockets are the variant's spires: commoner, lower
local FA_CHAND_CELL, FA_CHAND_SQUARES = 4, 0.30         -- the chandeliers: thin, cheap, dense

-- ------------------------------------------------------------ the structures

local BLIND = { blind = true }
local function rng_for(name)
    return game.rng_stream({ x = 0, y = 0, z = 0, seed = 0 }, "crystal_template:" .. name)
end
-- A spire: a crystal column four to ten tall, tapering, leaning a little.
local function spire(rng)
    schem.record_begin()
    local tall = 4 + rng:below(7)
    local d = schem.DIR16[rng:below(16) + 1]
    schem.push_path(blocks.crystal, { { 0.5, -0.5, 0.5, 0.9 }, { 0.5 + d[1] * 0.6, tall * 0.6, 0.5 + d[2] * 0.6, 0.6 }, { 0.5 + d[1] * 1.0, tall, 0.5 + d[2] * 1.0, 0.2 } }, BLIND)
    return schem.record_schematic({})
end
-- A cluster: three to five prisms fanning out and up from the root at
-- about forty-five degrees, half a block to two long.
local function cluster(rng, down)
    schem.record_begin()
    local sign = down and -1 or 1
    for _ = 1, 3 + rng:below(3) do
        local d = schem.DIR16[rng:below(16) + 1]
        local len = 0.6 + rng:below(4) * 0.45
        schem.push_path(blocks.crystal, { { 0.5, sign * 0.2, 0.5, 0.35 }, { 0.5 + d[1] * len, sign * len, 0.5 + d[2] * len, 0.15 } }, BLIND)
    end
    return schem.record_schematic({})
end
-- A geode pocket (the Fractured Amethyst Seam): a dark rind sunk into the
-- floor, a ragged druse of crystal inside it, a smoky fleck or two of
-- obsidian in the ring, and the bowl hollowed open through the top — air
-- carves in a schematic — so the pocket is concave and its glow spills up
-- into the corridor.
local function pocket(rng)
    schem.record_begin()
    local r = 1.6 + rng:below(4) * 0.3
    local ry = 1.2 + rng:below(3) * 0.3
    local rz = r * (0.8 + rng:below(3) * 0.15)
    schem.push_ellipsoid(blocks.dark_basalt, 0.5, 0.0, 0.5, r, ry, rz, { rough = 0.2, blind = true })
    schem.push_ellipsoid(blocks.crystal, 0.5, 0.0, 0.5, r - 0.4, ry - 0.35, rz - 0.4, { rough = 0.4, blind = true })
    for _ = 1, 1 + rng:below(2) do
        local d = schem.DIR16[rng:below(16) + 1]
        schem.push_ellipsoid(blocks.obsidian, 0.5 + d[1] * (r - 0.9), 0.1, 0.5 + d[2] * (rz - 0.9), 0.5, 0.4, 0.5, { rough = 0.3, blind = true })
    end
    schem.push_ellipsoid(game.AIR, 0.5, ry * 0.5, 0.5, r - 1.0, ry * 0.9, rz - 1.0, { rough = 0.25, blind = true })
    return schem.record_schematic({ [blocks.crystal] = 1, [blocks.obsidian] = 2, [game.AIR] = 3 })
end
-- A chandelier: a longer central needle and a ring of shorter ones round
-- it, each pencil-thin — a cell or so across, where the base's hangers are
-- half-block prisms — dropped from one ceiling root.
local function chandelier(rng)
    schem.record_begin()
    local drop = 3 + rng:below(4)
    schem.push_path(blocks.crystal, { { 0.5, 0.3, 0.5, 0.24 }, { 0.5, -drop, 0.5, 0.08 } }, BLIND)
    for _ = 1, 3 + rng:below(3) do
        local d = schem.DIR16[rng:below(16) + 1]
        local off = 0.5 + rng:below(3) * 0.25
        local short = 1 + rng:below(drop)
        schem.push_path(blocks.crystal, { { 0.5 + d[1] * off, 0.2, 0.5 + d[2] * off, 0.18 }, { 0.5 + d[1] * (off + 0.3), -short, 0.5 + d[2] * (off + 0.3), 0.06 } }, BLIND)
    end
    return schem.record_schematic({})
end
local BUILT = nil
local function structures()
    if BUILT then return BUILT end
    BUILT = { spires = {}, clusters = {}, hanging = {}, pockets = {}, chandeliers = {} }
    if game.schematic_shapes then
        for i = 1, 5 do BUILT.spires[i] = spire(rng_for("spire:" .. i)) end
        for i = 1, 5 do BUILT.clusters[i] = cluster(rng_for("cluster:" .. i), false) end
        for i = 1, 5 do BUILT.hanging[i] = cluster(rng_for("hanging:" .. i), true) end
        for i = 1, 5 do BUILT.pockets[i] = pocket(rng_for("pocket:" .. i)) end
        for i = 1, 5 do BUILT.chandeliers[i] = chandelier(rng_for("chandelier:" .. i)) end
    end
    return BUILT
end

-- ------------------------------------------------------------ the fields

tdw.cave_biome(ID, { -1, -0.33 }, function(ctx)      -- -0.12 until 2026-09-18 (37% of the caves); -0.30 (18%); a sixth since the six
    local caves = ctx.caves
    -- A level's floor, km under the dome: a slow wander (the floors were
    -- climbing a block a block at 1/260).
    local function floor_d(k)
        local level = LEVELS[k]
        return n.add(n.noise(level.floor_stream, 1 / 900, 1, 2.0 * level.wander, shape.HUMIDITY_STRETCH), n.const(level.floor))
    end
    -- Blocks above a level's floor (positive up).
    local function up(k)
        return n.mul(n.sub(floor_d(k), caves.D()), n.const(1000.0))
    end
    local function fault(k)
        return n.contour(LEVELS[k].fault, FAULT_FREQ, 2)
    end
    local function tall()
        return n.add(n.noise("cs_tall", 1 / 40, 1, TALL_VARY, shape.HUMIDITY_STRETCH), n.const(TALL))
    end
    local function width()
        return n.add(n.noise("cs_width", 1 / 30, 1, WIDTH_VARY, shape.HUMIDITY_STRETCH), n.const(WIDTH))
    end
    -- The corridor: within the half-width less what the cleft takes per
    -- block of height, under the ceiling, above the floor. **The deepest
    -- operand first** at every step (the engine holds a buffer per pending
    -- left operand, eight at most; the first cut nested the height under
    -- the width and was refused at ten).
    local function corridor(k)
        local across = n.sub(n.sub(width(), n.mul(up(k), n.const(NARROW / TALL))), fault(k))
        local under = n.min(across, n.sub(tall(), up(k)))
        return n.min(under, n.add(up(k), n.const(0.5)))
    end
    -- Geodes: blobs of a fine noise within GEODE_R of the fault line, at
    -- the corridor's heights; one that meets the corridor opens into it.
    local function geode(k)
        local band = n.min(n.sub(n.add(tall(), n.const(2.0)), up(k)), n.add(up(k), n.const(2.0)))
        local blob = n.min(band, n.mul(n.sub(n.noise("cs_geode", GEODE_FREQ, 1, 1.0), n.const(GEODE_MIN)), n.const(12.0)))
        return n.min(blob, n.sub(n.add(width(), n.const(GEODE_R)), fault(k)))
    end
    local function level_void(k)
        return n.max(corridor(k), geode(k))
    end
    local void = level_void(1)
    for k = 2, #LEVELS do
        void = n.max(void, level_void(k))
    end
    void = ctx.mine(void)
    local carve = ctx.compile("carve", void)
    local function step(f) return n.clamp(n.mul(f, n.const(1e4)), 0.0, 1.0) end
    -- Linings: slate two blocks in, dark basalt to four; a geode's shell
    -- crystal all round. (Code 2, the planar vein-blobs, is gone: the
    -- veins are the caves' own now.)
    --
    -- The variant's floor bed (codes 3 and 4): the rock within FA_FLOOR
    -- blocks of a corridor floor, on the variant's side of the line — fine
    -- crystal gravel, and patches of bare crystal in it where a fast noise
    -- glints ("sharp floor scree is mixed with fine, glittering crystal
    -- gravel"; the shard cover stays on both sides, which is the mixing).
    -- The corridors' own floor streams on purpose, via `up`: the bed lies
    -- exactly where the floors are. The geode shell moved from code 3 to 5
    -- so a shell running through the bed stays crystal all round — the
    -- greatest code wins.
    -- Two-sided, `geode()`'s band idiom: positive only from five blocks
    -- under a level's OWN floor datum to FA_FLOOR above it. One-sided
    -- (`FA_FLOOR - up(k)`) it was positive everywhere BELOW a floor too,
    -- and level 1's term, ~+500 throughout level 2's corridors, painted
    -- their walls and ceilings gravel. Five below reaches the bed's 3.0
    -- blocks into rock from a floor surface at up ~ -0.5, with margin.
    local function floor_near(k)
        return n.min(n.sub(n.const(FA_FLOOR), up(k)), n.add(up(k), n.const(5.0)))
    end
    local conditions = {
        n.const(1.0),
        n.const(-1.0),
        n.min(n.max(floor_near(1), floor_near(2)), ctx.side(1)),
        n.min(n.min(n.max(floor_near(1), floor_near(2)), ctx.side(1)),
            n.sub(n.noise("fa_glint", FA_GLINT_FREQ, 1, 1.0), n.const(FA_GLINT_MIN))),
        n.add(n.max(geode(1), geode(2)), n.const(1.5)),
    }
    -- The code needs no province cut: the layers paint only INTO rock
    -- within reach of a void, and the void is already the biome's own.
    local code = n.const(0.0)
    for k, c in ipairs(conditions) do
        code = n.max(code, n.mul(step(c), n.const(k)))
    end
    local depth = ctx.compile("depth", n.mul(void, n.const(-1.0)))
    local codes = ctx.compile("codes", code)
    local entries = {
        { code = 1, to = 2.0, material = blocks.slate },
        { code = 1, from = 2.0, to = 4.0, material = blocks.dark_basalt },
        { code = 3, to = 1.0, material = blocks.gravel },
        { code = 3, from = 1.0, to = 3.0, material = blocks.slate },
        { code = 4, to = 0.5, material = blocks.crystal },
        { code = 4, from = 0.5, to = 1.2, material = blocks.gravel },
        { code = 4, from = 1.2, to = 3.0, material = blocks.slate },
        { code = 5, to = 1.0, material = blocks.crystal },
        { code = 5, from = 1.0, to = 3.0, material = blocks.slate },
    }
    -- Crystal jutting from the walls: cells of it in the last block of rock
    -- before the void where a fine noise is high. A field, sampled to the
    -- cells, so a cluster is a ragged knob and not a slab.
    -- The last 1.2 blocks of rock before the void is `-1.2 < void < 0`,
    -- which is `0.6 - |void + 0.6|`: the void read ONCE (read twice it was
    -- nine buffers, past the engine's eight).
    local knobs = ctx.compile("knobs", ctx.mine(n.min(n.add(n.mul(n.abs(n.add(void, n.const(0.6))), n.const(-1.0)), n.const(0.6)),
        n.sub(n.noise("cs_cluster", CLUSTER_FREQ, 1, 1.0), n.const(CLUSTER_MIN)))))
    -- A cover stands only where air sits on rock, which in a chunk that is
    -- rock throughout is a cave floor: the take needs the province and the
    -- noise, not the void again.
    local shards = ctx.compile("shards", ctx.mine(n.sub(n.noise("cs_shard", SHARD_FREQ, 1, 1.0), n.const(SHARD_MIN))))
    local fills = {
        { carve = carve },
        { layers = true, depth = depth, code = codes, entries = entries },
        caves.vein_fill(ctx, void, VEIN_ZONE, VEIN_FREQ),
        { field = knobs, material = blocks.crystal, detail = { detail = "sampled" } },
        { cover = blocks.crystal, cells = 1, take = shards },
    }
    if game.schematic_shapes then
        local built = structures()
        -- Spires where the corridor pinches: the width noise low. The
        -- spires, the clusters and the hangers are what the variant's brief
        -- replaces, so all three keep to the base side (`ctx.base`); the
        -- knobs and the shards it only mixes into, so those stay shared.
        fills[#fills + 1] = { scatter = true, depth = depth, schematics = built.spires, cell = SPIRE_CELL, chance = SPIRE_SQUARES, salt = 411, sink = 1,
            stand = ctx.compile("stand_spire", ctx.base(n.sub(n.const(WIDTH - 0.3), width()))) }
        fills[#fills + 1] = { scatter = true, depth = depth, schematics = built.clusters, cell = CLUSTER_CELL, chance = CLUSTER_SQUARES, salt = 412, sink = 1,
            stand = ctx.compile("stand_cluster", ctx.base(n.sub(n.noise("cs_where", 1 / 9, 1, 1.0), n.const(0.05)))) }
        fills[#fills + 1] = { scatter = true, depth = carve, schematics = built.hanging, cell = CLUSTER_CELL, chance = CLUSTER_SQUARES, salt = 413, sink = 0,
            stand = ctx.compile("stand_hanging", ctx.base(n.sub(n.noise("cs_where", 1 / 9, 1, 1.0), n.const(0.05)))) }
        -- The variant's pockets sink into the floors, rim just proud, bowl
        -- open upward: the root a block under the surface block.
        fills[#fills + 1] = { scatter = true, depth = depth, schematics = built.pockets, cell = FA_POCKET_CELL, chance = FA_POCKET_SQUARES, salt = 414, sink = 2,
            stand = ctx.compile("stand_pocket", ctx.variant(n.sub(n.noise("fa_pocket", FA_POCKET_FREQ, 1, 1.0), n.const(FA_POCKET_MIN)))) }
        -- Its chandeliers hang where the base's hangers would: the same
        -- `cs_where` stream on purpose, so the ceilings' crowded spots are
        -- crowded in both dressings, and a lower bar makes them denser.
        fills[#fills + 1] = { scatter = true, depth = carve, schematics = built.chandeliers, cell = FA_CHAND_CELL, chance = FA_CHAND_SQUARES, salt = 415, sink = 0,
            stand = ctx.compile("stand_chandelier", ctx.variant(n.sub(n.noise("cs_where", 1 / 9, 1, 1.0), n.const(0.0)))) }
    end
    return fills
end)
tdw.cave_variant(ID, "Fractured Amethyst Seam")
