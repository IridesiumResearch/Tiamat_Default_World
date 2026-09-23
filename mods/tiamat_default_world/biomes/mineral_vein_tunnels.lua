-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- 2.5 Mineral Vein Tunnels (2026-09-18).
--
-- Constricted tabular corridors five to nine wide and four to seven high,
-- flat-roofed and flat-floored, following fracture lines. Rough fractured
-- walls in horizontal strata — granite, banded ironstone, grey slate —
-- striped with jagged ribbons of raw ore; scree and tailings on the floor.
-- Inorganics only: dendritic mineral frostings flat on the walls, cubic
-- clusters of pyrite and galena, rust streaks; ore nodes jutting from the
-- stone like knuckles, slab-collapses, quartz seams.
--
-- THE CORRIDORS are three levels of them. A level's floor lies at a depth
-- that wanders slowly; its passages are the lines along which either of
-- two contour noises is zero — the fractures, crossing into a network —
-- and a passage is a BOX in section: its half-width from the line, its
-- height from the floor, square at the corners. A fine noise roughens the
-- walls, the fractured face.
--
-- THE STRATA are a noise drawn out flat (it changes only with height), cut
-- into bands: granite under one value, slate over, and between them the
-- banded ironstone, a second finer flat noise alternating `iron_ore` with
-- `dark_basalt` through the band. Two more flat noises, near zero, are the
-- ore ribbons (`copper_ore`, and `lead_ore`, which is galena).
--
-- Materials: `granite`, `slate`, `dark_basalt`, the ores, `gravel` (the
-- scree), `calcite` (the frostings), `rust_red_sandstone` (the rust),
-- `crystal` (the quartz: the caves' own veins, closer here), `lead_ore` (the
-- galena cubes). **One new material, `pyrite`; no plant** — the brief is
-- inorganics only.
--
-- THE VARIANT (2026-09-23): **Oxidized Copper Chasm** — the same corridors
-- on the far side of the `cave_variant` noise (caves.lua), further gone in
-- weathering. The iron knuckles and the pyrite-galena cube clusters keep to
-- the base dressing; in their place, "exposed, branching native copper
-- dendrites shaped like antlers" grow off the floors and hang from the
-- ceilings — thin trunks of `copper_ore` with two to four tines, in the
-- knuckles' own patches. The walls are "heavily weathered": crusts of
-- verdigris and malachite (both `copper_ore`, the one green-crusted rock),
-- powdery ochre (`ochre_sandstone`), and the base's own rust streaks let
-- run three times as far. On the floors, low sulfur vents — craters of
-- `sulfur` rimmed with `pyrite`, whose "faint heat shimmer" is the
-- sulfur's own steady glow. No new blocks; the carve, the strata, the
-- ribbons, the frostings, the slab-collapses and the quartz seams are
-- shared with the base.

local blocks = tdw.blocks
local shape = tdw.shape
local schem = tdw.schem
local n = shape.node
local ID = "mineral_vein_tunnels"
local FLAT = shape.HUMIDITY_STRETCH

local LEVELS = {
    { floor = 0.40, wander = 0.20, a = "mv_frac_a1", b = "mv_frac_b1", floor_stream = "mv_floor1" },
    { floor = 0.85, wander = 0.25, a = "mv_frac_a2", b = "mv_frac_b2", floor_stream = "mv_floor2" },
    { floor = 1.30, wander = 0.20, a = "mv_frac_a3", b = "mv_frac_b3", floor_stream = "mv_floor3" },
}
local FRAC_A, FRAC_B = 1 / 150, 1 / 230                 -- the two fracture families
local HALF, HALF_VARY = 3.5, 1.0                        -- half-width: 5 to 9 across
local TALL, TALL_VARY = 5.5, 1.5                        -- 4 to 7 high
local ROUGH_FREQ, ROUGH = 1 / 2.5, 0.7                  -- the fractured face
local STRATA_FREQ, STRATA_STRETCH = 1 / 6, { x = 16, z = 16 }
local GRANITE_UNDER, IRON_BAND = -0.12, { -0.02, 0.10 }
local BAND_FREQ = 1 / 1.6                               -- the ironstone's own fine banding
local RIBBON_FREQ, RIBBON_W, RIBBON_JAG = 1 / 9, 0.10, 0.08
local RUST_FREQ, RUST_MIN = 1 / 3, 0.30                 -- rust streaks: a noise drawn out DOWN the wall
local FROST_FREQ, FROST_W = 1 / 2.5, 0.16               -- the dendritic frostings (0.05 in the first cut: two blocks in a tunnel)
local FROST_PATCH_FREQ, FROST_PATCH_MIN = 1 / 10, -0.08
local KNOB_FREQ, KNOB_MIN = 1 / 1.8, 0.33               -- ore nodes, into the air
local KNOB_PATCH_FREQ, KNOB_PATCH_MIN = 1 / 14, 0.05
local CUBE_CELL, CUBE_SQUARES = 3, 0.35               -- (5, 0.28 in the first cut: three blocks of pyrite in a tunnel)
local SLAB_CELL, SLAB_SQUARES = 16, 0.30
local QUARTZ_ZONE, QUARTZ_FREQ = -0.10, 1 / 40          -- the crystal veins: most of this rock, and close
-- The Oxidized Copper Chasm's own numbers. New streams are prefixed
-- `occ_`; a Chasm field reading an `mv_` stream is on purpose and says so
-- where it does. The weathering spends ONE new noise between its crusts —
-- verdigris where it runs high, ochre in a disjoint band of the same
-- stream — and the rust is the base's `mv_rust` with its threshold let
-- down, so the Chasm's streaks are the base's streaks, further run.
local VERD_FREQ, VERD_MIN = 1 / 7, 0.24                 -- verdigris/malachite: crusts a few blocks across
local OCHRE_BAND = { -0.36, -0.18 }                     -- powdery ochre: the same noise, low
local OCC_RUST_MIN = 0.10                               -- the rust let run (RUST_MIN is 0.30)
local DEND_CELL, DEND_SQUARES = 4, 0.45                 -- copper dendrites, in the knuckles' patches
local VENT_CELL, VENT_SQUARES = 12, 0.40                -- sulfur vents: low, and not rare

-- ------------------------------------------------------------ the structures

local BLIND = { blind = true }
local function rng_for(name)
    return game.rng_stream({ x = 0, y = 0, z = 0, seed = 0 }, "mineral_template:" .. name)
end
-- The mask of a cube of `s` cells a side (2 or 3) at cell (ox, oy, oz) of
-- its block.
local function cube_mask(s, ox, oy, oz)
    local m = 0
    for z = oz, oz + s - 1 do
        for y = oy, oy + s - 1 do
            for x = ox, ox + s - 1 do
                m = m | (1 << (x + 3 * y + 9 * z))
            end
        end
    end
    return m
end
-- A cluster of cubes on the floor: two to five, each two thirds of a block
-- or a whole one, stacked and huddled. Pyrite, or galena (`lead_ore`).
local function cubes(rng, material)
    schem.record_begin()
    local placed = 0
    for _ = 1, 2 + rng:below(4) do
        local dx, dz = rng:below(3) - 1, rng:below(3) - 1
        local dy = (placed > 1 and rng:below(3) == 0) and 1 or 0
        if rng:below(2) == 0 then
            schem.push_cells(material, dx, 1 + dy, dz, cube_mask(3, 0, 0, 0))
        else
            schem.push_cells(material, dx, 1 + dy, dz, cube_mask(2, rng:below(2), 0, rng:below(2)))
        end
        placed = placed + 1
    end
    return schem.record_schematic({})
end
-- A slab-collapse: one to three flat slabs of slate fallen from the roof,
-- tilted and overlapping, a low obstacle.
local function slabs(rng)
    schem.record_begin()
    for i = 1, 1 + rng:below(3) do
        local d = schem.DIR16[rng:below(16) + 1]
        local rx, rz = 1.6 + rng:below(3) * 0.5, 1.1 + rng:below(3) * 0.3
        local x, z = 0.5 + d[1] * (i - 1) * 0.9, 0.5 + d[2] * (i - 1) * 0.9
        schem.push_ellipsoid(blocks.slate, x, 1.0 + (i - 1) * 0.35, z, rx, 0.32, rz, { rough = 0.12, blind = true })
    end
    return schem.record_schematic({})
end
-- The Chasm's copper dendrite: a native-copper antler grown out of the
-- rock. A leaning trunk two to four blocks long, and two to four tines
-- forking off its upper knuckles, every branch a thin tapering path of
-- `copper_ore`. `sign` +1 grows off a floor; -1 hangs from a ceiling,
-- which is the same antler with its y run the other way.
local function dendrite(rng, sign)
    schem.record_begin()
    local d = schem.DIR16[rng:below(16) + 1]
    local h = (2 + rng:below(3)) * sign
    local lean = 0.4 + rng:below(3) * 0.25
    local y0 = sign > 0 and 0.1 or 0.3      -- the ivy's own root height, hanging (mossy_limestone.lua)
    local knuckles = {
        { 0.5, y0, 0.5, 0.42 },
        { 0.5 + d[1] * lean, y0 + h * 0.55, 0.5 + d[2] * lean, 0.30 },
        { 0.5 + d[1] * lean * 1.8, y0 + h, 0.5 + d[2] * lean * 1.8, 0.22 },
    }
    schem.push_path(blocks.copper_ore, knuckles, BLIND)
    for _ = 1, 2 + rng:below(3) do
        local from = knuckles[2 + rng:below(2)]
        local fd = schem.DIR16[rng:below(16) + 1]
        local fl = 0.9 + rng:below(4) * 0.4
        schem.push_path(blocks.copper_ore, {
            { from[1], from[2], from[3], 0.26 },
            { from[1] + fd[1] * fl, from[2] + (1 + rng:below(2)) * sign, from[3] + fd[2] * fl, 0.16 },
        }, BLIND)
    end
    return schem.record_schematic({})
end
-- A sulfur vent: a low crusted crater. A thin apron of sulfur over the
-- floor, a raised rim of lumps round the throat, and two or three small
-- pyrite cubes bright on the rim — pushed last, so they win their cells.
local function vent(rng)
    schem.record_begin()
    local r = 1.2 + rng:below(3) * 0.4
    schem.push_ellipsoid(blocks.sulfur, 0.5, 0.9, 0.5, r + 0.9, 0.45, r + 0.9, { rough = 0.35, blind = true })
    for k = 0, 7 do
        local d = schem.DIR16[(k * 2 + rng:below(2)) % 16 + 1]
        schem.push_ellipsoid(blocks.sulfur, 0.5 + d[1] * r, 1.1 + rng:below(3) * 0.15, 0.5 + d[2] * r, 0.7, 0.55, 0.7, { rough = 0.4, blind = true })
    end
    for _ = 1, 2 + rng:below(2) do
        local d = schem.DIR16[rng:below(16) + 1]
        schem.push_cells(blocks.pyrite, math.floor(0.5 + d[1] * r), 1, math.floor(0.5 + d[2] * r), cube_mask(2, rng:below(2), 0, rng:below(2)))
    end
    return schem.record_schematic({})
end
local BUILT = nil
local function structures()
    if BUILT then return BUILT end
    BUILT = { cubes = {}, slabs = {}, dendrites_up = {}, dendrites_down = {}, vents = {} }
    if game.schematic_shapes then
        for i = 1, 4 do BUILT.cubes[#BUILT.cubes + 1] = cubes(rng_for("pyrite:" .. i), blocks.pyrite) end
        for i = 1, 2 do BUILT.cubes[#BUILT.cubes + 1] = cubes(rng_for("galena:" .. i), blocks.lead_ore) end
        for i = 1, 4 do BUILT.slabs[i] = slabs(rng_for("slab:" .. i)) end
        for i = 1, 4 do BUILT.dendrites_up[i] = dendrite(rng_for("dendrite_up:" .. i), 1) end
        for i = 1, 3 do BUILT.dendrites_down[i] = dendrite(rng_for("dendrite_down:" .. i), -1) end
        for i = 1, 3 do BUILT.vents[i] = vent(rng_for("vent:" .. i)) end
    end
    return BUILT
end

-- ------------------------------------------------------------ the fields

tdw.cave_biome(ID, { -0.33, -0.15 }, function(ctx)
    local caves = ctx.caves
    local function floor_d(k)
        local level = LEVELS[k]
        return n.add(n.noise(level.floor_stream, 1 / 900, 1, 2.0 * level.wander, FLAT), n.const(level.floor))
    end
    -- Blocks above a level's floor.
    local function up(k)
        return n.mul(n.sub(floor_d(k), caves.D()), n.const(1000.0))
    end
    -- Blocks from the nearer fracture of a level.
    local function across(k)
        return n.min(n.contour(LEVELS[k].a, FRAC_A, 1), n.contour(LEVELS[k].b, FRAC_B, 1))
    end
    local function half()
        return n.add(n.noise("mv_half", 1 / 40, 1, HALF_VARY, FLAT), n.const(HALF))
    end
    local function tall()
        return n.add(n.noise("mv_tall", 1 / 30, 1, TALL_VARY, FLAT), n.const(TALL))
    end
    -- A passage: a box in section. The height FIRST (it carries the dome).
    local function passage(k)
        local h = up(k)
        local vertical = n.min(n.add(h, n.const(0.5)), n.sub(tall(), up(k)))
        return n.min(vertical, n.sub(half(), across(k)))
    end
    local void = passage(1)
    for k = 2, #LEVELS do
        void = n.max(void, passage(k))
    end
    void = n.add(void, n.noise("mv_rough", ROUGH_FREQ, 1, ROUGH))
    void = ctx.mine(void)
    local carve = ctx.compile("carve", void)
    local function step(f) return n.clamp(n.mul(f, n.const(1e4)), 0.0, 1.0) end
    -- The floor's rock: under a level's floor and in its passages.
    local floorish = nil
    for k = 1, #LEVELS do
        local f = n.min(n.mul(up(k), n.const(-1.0)), n.sub(n.add(half(), n.const(1.0)), across(k)))
        floorish = floorish and n.max(floorish, f) or f
    end
    local strata = n.noise("mv_strata", STRATA_FREQ, 1, 1.0, STRATA_STRETCH)
    local function in_band()
        local s = n.noise("mv_strata", STRATA_FREQ, 1, 1.0, STRATA_STRETCH)
        return n.min(n.sub(s, n.const(IRON_BAND[1])), n.sub(n.const(IRON_BAND[2]), n.noise("mv_strata", STRATA_FREQ, 1, 1.0, STRATA_STRETCH)))
    end
    local function ribbon(stream)
        local jag = n.noise(stream .. "_jag", 1 / 2, 1, RIBBON_JAG)
        return n.sub(n.const(RIBBON_W), n.abs(n.add(n.noise(stream, RIBBON_FREQ, 1, 1.0, STRATA_STRETCH), jag)))
    end
    -- The Chasm's weathering (codes 8..10): crusts on the variant side of
    -- the `cave_variant` line, `ctx.side(1)` minned in. One new noise
    -- between the verdigris and the ochre; the ninth condition reads the
    -- base's own `mv_rust` on purpose, so where the base shows a streak the
    -- Chasm shows the same streak grown wide. Scree stays the highest code:
    -- a weathered wall is the brief, a weathered floor is still scree.
    local function weather()
        return n.noise("occ_weather", VERD_FREQ, 1, 1.0)
    end
    local conditions = {
        n.const(1.0),                                                                               -- 1 slate
        n.sub(n.const(GRANITE_UNDER), strata),                                                      -- 2 granite
        in_band(),                                                                                  -- 3 ironstone: basalt
        n.min(in_band(), n.noise("mv_band", BAND_FREQ, 1, 1.0, STRATA_STRETCH)),                   -- 4 ironstone: iron
        ribbon("mv_ribbon_cu"),                                                                     -- 5 a copper ribbon
        ribbon("mv_ribbon_pb"),                                                                     -- 6 a galena ribbon
        n.sub(n.noise("mv_rust", RUST_FREQ, 1, 1.0, { y = 8 }), n.const(RUST_MIN)),                -- 7 a rust streak
        n.min(n.min(n.sub(weather(), n.const(OCHRE_BAND[1])), n.sub(n.const(OCHRE_BAND[2]), weather())),
            ctx.side(1)),                                                                           -- 8 powdery ochre
        n.min(n.sub(n.noise("mv_rust", RUST_FREQ, 1, 1.0, { y = 8 }), n.const(OCC_RUST_MIN)),
            ctx.side(1)),                                                                           -- 9 the rust let run
        n.min(n.sub(weather(), n.const(VERD_MIN)), ctx.side(1)),                                    -- 10 verdigris and malachite
        floorish,                                                                                   -- 11 scree
    }
    local code = n.const(0.0)
    for k, c in ipairs(conditions) do
        code = n.max(code, n.mul(step(c), n.const(k)))
    end
    local depth = ctx.compile("depth", n.mul(void, n.const(-1.0)))
    local codes = ctx.compile("codes", code)
    local entries = {
        { code = 1, to = 2.5, material = blocks.slate },
        { code = 2, to = 2.5, material = blocks.granite },
        { code = 3, to = 2.5, material = blocks.dark_basalt },
        { code = 4, to = 2.5, material = blocks.iron_ore },
        { code = 5, to = 2.5, material = blocks.copper_ore },
        { code = 6, to = 2.5, material = blocks.lead_ore },
        { code = 7, to = 0.4, material = blocks.rust_red_sandstone },
        { code = 7, from = 0.4, to = 2.5, material = blocks.slate },
        { code = 8, to = 0.4, material = blocks.ochre_sandstone },
        { code = 8, from = 0.4, to = 2.5, material = blocks.slate },
        { code = 9, to = 0.4, material = blocks.rust_red_sandstone },
        { code = 9, from = 0.4, to = 2.5, material = blocks.slate },
        { code = 10, to = 0.5, material = blocks.copper_ore },
        { code = 10, from = 0.5, to = 2.5, material = blocks.slate },
        { code = 11, to = 1.0, material = blocks.gravel },
        { code = 11, from = 1.0, to = 2.5, material = blocks.slate },
    }
    -- The frostings: in the last 0.6 of rock before the air, `0.3 - |void +
    -- 0.3|` (the void read once), where a fine noise is near zero — its
    -- zero lines branch — in patches.
    local skin = n.add(n.mul(n.abs(n.add(void, n.const(0.3))), n.const(-1.0)), n.const(0.3))   -- the void FIRST
    local frost = ctx.compile("frost", ctx.mine(n.min(n.min(skin, n.mul(n.sub(n.const(FROST_W), n.abs(n.noise("mv_frost", FROST_FREQ, 2, 1.0))), n.const(20.0))),
        n.sub(n.noise("mv_frost_patch", FROST_PATCH_FREQ, 1, 1.0), n.const(FROST_PATCH_MIN)))))
    -- The ore nodes: knuckles of iron ore in the first 0.9 of AIR off the
    -- rock, where a blob noise is high, in patches. Base side only
    -- (`ctx.base`): in the Chasm the knuckles' place is taken by the
    -- copper dendrites below.
    local film = n.add(n.mul(n.abs(n.sub(void, n.const(0.45))), n.const(-1.0)), n.const(0.45))
    local knobs = ctx.compile("knobs", ctx.base(n.min(n.min(film, n.mul(n.sub(n.noise("mv_knob", KNOB_FREQ, 1, 1.0), n.const(KNOB_MIN)), n.const(6.0))),
        n.sub(n.noise("mv_knob_patch", KNOB_PATCH_FREQ, 1, 1.0), n.const(KNOB_PATCH_MIN)))))
    local fills = {
        { carve = carve },
        { layers = true, depth = depth, code = codes, entries = entries },
        caves.vein_fill(ctx, void, QUARTZ_ZONE, QUARTZ_FREQ),   -- the quartz seams
        { field = frost, material = blocks.calcite, detail = { detail = "sampled" } },
        { field = knobs, material = blocks.iron_ore, detail = { detail = "sampled" } },
    }
    if game.schematic_shapes then
        local built = structures()
        -- The cube clusters keep to the base side (`ctx.base`); the slabs
        -- fall on both — a roof lets go whatever colour the walls are.
        fills[#fills + 1] = { scatter = true, depth = depth, schematics = built.cubes, cell = CUBE_CELL, chance = CUBE_SQUARES, salt = 441, sink = 1,
            stand = ctx.compile("stand_cubes", ctx.base(n.sub(n.noise("mv_cubes", 1 / 11, 1, 1.0), n.const(-0.15)))) }
        fills[#fills + 1] = { scatter = true, depth = depth, schematics = built.slabs, cell = SLAB_CELL, chance = SLAB_SQUARES, salt = 442, sink = 1,
            stand = ctx.compile("stand_slabs", ctx.mine(n.const(1.0))) }
        -- The Chasm's dendrites take the knuckles' own patches
        -- (`mv_knob_patch`, reused on purpose): where the base grows iron
        -- knuckles the variant grows copper antlers — the same lodes,
        -- further oxidized. Off the floors rooted in the rock, and off the
        -- ceilings the vines' way: the depth positive in the VOID, the
        -- crossing stamped at rock over air.
        local antlers = ctx.compile("stand_dendrites", ctx.variant(n.sub(n.noise("mv_knob_patch", KNOB_PATCH_FREQ, 1, 1.0), n.const(KNOB_PATCH_MIN))))
        fills[#fills + 1] = { scatter = true, depth = depth, schematics = built.dendrites_up, cell = DEND_CELL, chance = DEND_SQUARES, salt = 443, sink = 1,
            stand = antlers }
        fills[#fills + 1] = { scatter = true, depth = carve, schematics = built.dendrites_down, cell = DEND_CELL, chance = DEND_SQUARES, salt = 444, sink = 0,
            stand = antlers }
        -- The sulfur vents want no patch noise: the chance and the cell
        -- are the spacing, anywhere the Chasm has a floor.
        fills[#fills + 1] = { scatter = true, depth = depth, schematics = built.vents, cell = VENT_CELL, chance = VENT_SQUARES, salt = 445, sink = 1,
            stand = ctx.compile("stand_vents", ctx.variant(n.const(1.0))) }
    end
    return fills
end)
tdw.cave_variant(ID, "Oxidized Copper Chasm")
