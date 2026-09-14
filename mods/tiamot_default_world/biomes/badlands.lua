-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- 2.1 Badlands: the Glass Waste's wet half.
--
-- The brief (2026-09-14):
--
--   Topography: razor-sharp ridge crests and steep fluted mud hills divided
--   by labyrinthine drainage gullies; slopes of 35 to 60 degrees dissected
--   by water-carved rills into razorback fins and miniature clay canyons.
--   Surface: rhythmic horizontal, slightly wavy bands of soft sandstones,
--   clays and volcanic ash* — stark charcoal*, dull lavender dried mud*. Dry
--   slopes with a swollen, cracked "popcorn" clay crust and brittle chert.
--   Vegetation: 95% barren; rare dead sagebrush* and grass only at the base
--   of deep shaded gullies; stunted trees of the mesa's kind in drying mud.
--   Drainage: dry clay runoffs, mud-choked gully floors, subterranean
--   piping voids.
--   Accents: knife-edge ridge paths, dry mud-crack flats in the ravine
--   bottoms, fallen petrified trunks bridging deep gullies. Not a tall
--   biome; a good place for erosion.
--
-- THE GROUND, as terms (a map cannot tile the Glass Waste's ring — see the
-- mesa's file), all of it the shapes water cuts:
--
--   * HILLS: a tent on a slow noise — `1 - 2|n|` — so every hill has a
--     crest, never a dome, about twenty blocks at the most.
--   * FINS: a finer tent over the hills' upper parts, fourteen blocks, whose
--     crests are the knife-edge ridges; the two together give slopes of about
--     40 to 55 degrees.
--   * RILLS: grooves of a noise stretched four times up the y axis, so each
--     runs straight down a slope, two and a half blocks deep.
--   * GULLIES: two contours of different grain, the labyrinth, eight
--     blocks deep with flat floors.
--   * PIPING: tubes where two 3D noises are both near zero, cut twenty
--     blocks into the terrain field — which only ever opens the ground within
--     twenty blocks of the surface, so they are voids under the slopes and
--     never caves.
--
-- THE BANDS are the mesa's fold: the height over the smooth ground, with a
-- slow wave of two blocks added, folded into a zig-zag the code rounds to
-- five materials. Stand-ins until named: the soft sandstone is `sand`, the
-- clay and the popcorn crust `dry_clay`, the chert `creek_bed`, the
-- petrified trunks `granite`.

local blocks = tdw.blocks
local shape = tdw.shape
local n = shape.node
local schem = tdw.schem

local ID = "badlands"

local HILL_FREQ, HILL_H = 1 / 100, 0.020
local FIN_FREQ, FIN_H = 1 / 28, 0.014                  -- fine and steep: the razorbacks
local RILL_FREQ, RILL_STRETCH, RILL_D = 1 / 7, 4.0, 0.0025
local GULLY_A_FREQ, GULLY_B_FREQ, GULLY_W, GULLY_D = 1 / 90, 1 / 150, 4.0, 0.008
local PIPE_FREQ, PIPE_W, PIPE_CUT = 1 / 24, 0.035, 0.020
local WAVE_FREQ, WAVE_AMP = 1 / 60, 0.004
-- The fold only zig-zags over 0 to twice its first point, so the height is
-- lifted by BAND_LIFT into that range first: without it everything under
-- the smooth ground folded to one side and rounded to the fifth material.
local BAND_LIFT = 0.03
local BAND_FOLDS = { 0.04, 0.019, 0.0105 }             -- five materials up a tooth of ten blocks and down again
local CRUST_FREQ, CRUST_MIN = 1 / 11, 0.42               -- popcorn crust patches on the slopes: few enough that the bands show
local CHERT_FREQ, CHERT_MIN = 1 / 5, 0.47
-- The structures.
local TREE_CELL, TREE_SQUARES = 40, 0.2
local TRUNK_CELL, TRUNK_SQUARES = 48, 0.4

-- ------------------------------------------------------------ the ground

local function tent(stream, freq)
    return n.add(n.mul(n.abs(n.noise(stream, freq, 2, 1.0)), n.const(-2.0)), n.const(1.0))
end
-- 1 on a gully's floor, falling to 0 up its walls: the nearer of two
-- contours.
local function gully_w()
    local a = n.clamp(n.mul(n.add(n.contour("bl_gully_a", GULLY_A_FREQ, 2), n.const(-GULLY_W)), n.const(-0.7)), 0.0, 1.0)
    return n.max(a, n.clamp(n.mul(n.add(n.contour("bl_gully_b", GULLY_B_FREQ, 2), n.const(-GULLY_W)), n.const(-0.7)), 0.0, 1.0))
end

-- The badlands' terms of the terrain, km, added to the depth.
function shape.badlands_terms()
    local hills = tent("bl_hill", HILL_FREQ)
    -- The fins over the upper half of the hills: `hill * fin`, both tents.
    local acc = n.mul(n.mul(tent("bl_fin", FIN_FREQ), hills), n.const(FIN_H))
    acc = n.add(acc, n.mul(tent("bl_hill", HILL_FREQ), n.const(HILL_H)))
    -- Rills straight down the slopes.
    local rill = n.clamp(n.add(n.mul(n.abs(n.noise("bl_rill", RILL_FREQ, 1, 1.0, { y = RILL_STRETCH })), n.const(-6.0)), n.const(1.0)), 0.0, 1.0)
    acc = n.sub(acc, n.mul(rill, n.const(RILL_D)))
    -- The gullies, cut down to a flat floor.
    acc = n.sub(acc, n.mul(gully_w(), n.const(GULLY_D)))
    -- The piping voids.
    local a = n.clamp(n.mul(n.add(n.abs(n.noise("bl_pipe_a", PIPE_FREQ, 1, 1.0)), n.const(-PIPE_W)), n.const(-40.0)), 0.0, 1.0)
    local b = n.clamp(n.mul(n.add(n.abs(n.noise("bl_pipe_b", PIPE_FREQ, 1, 1.0)), n.const(-PIPE_W)), n.const(-40.0)), 0.0, 1.0)
    return n.sub(acc, n.mul(n.mul(a, b), n.const(PIPE_CUT)))
end

tdw.biomes[ID].ring_mode = "verdant"
tdw.biomes[ID].lazy = true
tdw.biomes[ID].soil = blocks.dry_clay

-- ------------------------------------------------------------ the structures

local BLIND = { blind = true }

-- A stunted tree of the mesa's kind: a crooked grey stem two to three tall,
-- anchored in a skirt of drying mud, one or two flat pads of needles.
local function stunted(rng)
    schem.record_begin()
    local tall = 2 + rng:below(2)
    local d = schem.DIR16[rng:below(16) + 1]
    local stem = { { 0.5, -1.0, 0.5, 0.36 }, { 0.5 + d[1] * 0.4, tall * 0.6, 0.5 + d[2] * 0.4, 0.28 }, { 0.5 + d[1] * 0.9, tall, 0.5 + d[2] * 0.9, 0.18 } }
    schem.push_path(blocks.juniper_wood, stem, BLIND)
    for _ = 1, 1 + rng:below(2) do
        local w = schem.DIR16[rng:below(16) + 1]
        schem.push_ellipsoid(blocks.juniper_needles, stem[3][1] + w[1] * 0.6, tall + 0.2, stem[3][3] + w[2] * 0.6, 1.0, 0.35, 1.0,
            { rough = 0.45, blind = true })
    end
    schem.push_ellipsoid(blocks.dried_mud, 0.5, 0.5, 0.5, 1.6, 0.45, 1.6, { rough = 0.3, blind = true })
    return schem.record_schematic({ [blocks.juniper_wood] = 2, [blocks.dried_mud] = 1 })
end

-- A fallen petrified trunk: eighteen blocks or so of stone log lying at the
-- rim, so one that fell across a gully bridges it.
local function trunk(rng)
    schem.record_begin()
    local d = schem.DIR16[rng:below(16) + 1]
    local half = 8 + rng:below(4)
    schem.push_path(blocks.granite, {
        { 0.5 - d[1] * half, 0.6, 0.5 - d[2] * half, 0.9 },
        { 0.5 + d[1] * half, 0.5, 0.5 + d[2] * half, 0.7 },
    }, { rough = 0.15, blind = true })
    -- A snapped stub of root at the thick end.
    schem.push_path(blocks.granite, {
        { 0.5 - d[1] * half, 0.6, 0.5 - d[2] * half, 0.8 },
        { 0.5 - d[1] * (half + 1.5), -0.4, 0.5 - d[2] * (half + 1.5), 0.5 },
    }, BLIND)
    return schem.record_schematic({})
end

local BUILT = nil
local function structures()
    if BUILT then
        return BUILT
    end
    local out = { trees = {}, trunks = {} }
    if game.schematic_shapes then
        local function rng_for(name)
            return game.rng_stream({ x = 0, y = 0, z = 0, seed = 0 }, "badlands_template:" .. name)
        end
        for i = 1, 4 do out.trees[i] = stunted(rng_for("tree:" .. i)) end
        for i = 1, 4 do out.trunks[i] = trunk(rng_for("trunk:" .. i)) end
        game.log(string.format("tiamot_default_world badlands: cut %d stunted trees, %d petrified trunks", #out.trees, #out.trunks))
    end
    BUILT = out
    return out
end

-- ------------------------------------------------------------ the fills

tdw.build_biome(ID, function(ctx)
    local function masked(field)
        local mask = tdw.biome_mask(n, ID)
        return mask and n.min(field, mask) or field
    end
    local function off_river(field, blocks_out)
        return shape.river_exclude and shape.river_exclude(field, blocks_out) or field
    end
    local function step(field)
        return n.clamp(n.mul(field, n.const(1e4)), 0.0, 1.0)
    end
    -- The bands: 1..5 by the fold of the wavy height over the smooth ground.
    local fold = n.add(n.add(n.mul(n.add(shape.depth(), shape.relief_node()), n.const(-1.0)), n.noise("bl_wave", WAVE_FREQ, 1, WAVE_AMP)),
        n.const(BAND_LIFT))
    for _, at in ipairs(BAND_FOLDS) do
        fold = n.abs(n.sub(fold, n.const(at)))
    end
    local code = n.clamp(n.add(n.mul(fold, n.const(4.0 / BAND_FOLDS[#BAND_FOLDS])), n.const(1.0)), 1.0, 5.0)
    -- 6: the popcorn crust in patches; 7: brittle chert.
    code = n.max(code, n.mul(step(n.sub(n.noise("bl_crust", CRUST_FREQ, 1, 1.0), n.const(CRUST_MIN))), n.const(6)))
    code = n.max(code, n.mul(step(n.sub(n.noise("bl_chert", CHERT_FREQ, 1, 1.0), n.const(CHERT_MIN))), n.const(7)))
    -- 8: a gully's walls, dry clay runoff; 9: its floor, mud-choked in the
    -- middle (10) and cracked dry mud either side.
    code = n.max(code, n.mul(step(n.sub(gully_w(), n.const(0.5))), n.add(n.const(8), n.mul(step(n.sub(gully_w(), n.const(0.8))),
        n.add(n.const(1), step(n.sub(n.noise("bl_mud", 1 / 9, 1, 1.0), n.const(0.1))))))))
    local mask = tdw.biome_mask(n, ID)
    if mask then
        code = n.mul(code, step(mask))
    end
    local depth = shape.compile("biome.badlands.depth", shape.terrain(false))
    local codes = shape.compile("biome.badlands.codes", code)
    local km, deep = 0.001, 400 * 0.001
    local BANDS = { blocks.volcanic_ash, blocks.charcoal, blocks.dried_mud, blocks.sand, blocks.dry_clay }
    local entries = {}
    for i, material in ipairs(BANDS) do
        entries[#entries + 1] = { code = i, to = deep, material = material }
    end
    local more = {
        { code = 6, to = 1 * km, material = blocks.dry_clay },
        { code = 6, from = 1 * km, to = deep, material = blocks.dried_mud },
        { code = 7, to = 1 * km, material = blocks.creek_bed },
        { code = 7, from = 1 * km, to = deep, material = blocks.charcoal },
        { code = 8, to = 2 * km, material = blocks.dry_clay },
        { code = 8, from = 2 * km, to = deep, material = blocks.dried_mud },
        { code = 9, to = 2 * km, material = blocks.dried_mud },
        { code = 9, from = 2 * km, to = deep, material = blocks.dry_clay },
        { code = 10, to = 1 * km, material = blocks.mud },
        { code = 10, from = 1 * km, to = deep, material = blocks.dried_mud },
    }
    for _, e in ipairs(more) do entries[#entries + 1] = e end
    -- Dead sagebrush and a little grass, only on the deep gullies' floors.
    local floor = n.sub(gully_w(), n.const(0.8))
    local sage = shape.compile("biome.badlands.sage", masked(off_river(n.min(floor, n.sub(n.noise("bl_sage", 1.4, 1, 1.0), n.const(0.36))), shape.RIVER_BAR or 0)))
    local grass = shape.compile("biome.badlands.grass", masked(off_river(n.min(floor, n.sub(n.noise("bl_grass", 1.5, 1, 1.0), n.const(0.40))), shape.RIVER_BAR or 0)))
    local fills = {
        { layers = true, depth = depth, code = codes, entries = entries, body = true },
        { cover = blocks.dead_sagebrush, cells = 2, take = sage },
        { cover = blocks.tall_grass, cells = 2, take = grass },
    }
    if game.schematic_shapes then
        local built = structures()
        local function scatter(name, list, field, cell, chance, salt, above)
            fills[#fills + 1] = { scatter = true, depth = depth, schematics = list, cell = cell, chance = chance, salt = salt, sink = 1,
                above = above, stand = shape.compile("biome.badlands.stand_" .. name, masked(off_river(field, (shape.RIVER_BAR or 0) + 6))) }
        end
        scatter("tree", built.trees, n.sub(gully_w(), n.const(0.8)), TREE_CELL, TREE_SQUARES, 111, 0.006)
        -- The trunks at a gully's rim: just past its walls.
        scatter("trunk", built.trunks, n.min(n.add(n.contour("bl_gully_a", GULLY_A_FREQ, 2), n.const(-(GULLY_W + 1.0))),
            n.add(n.mul(n.contour("bl_gully_a", GULLY_A_FREQ, 2), n.const(-1.0)), n.const(GULLY_W + 3.5))), TRUNK_CELL, TRUNK_SQUARES, 112, 0.004)
    end
    return fills
end)
