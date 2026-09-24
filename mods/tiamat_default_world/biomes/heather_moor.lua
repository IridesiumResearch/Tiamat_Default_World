-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- 3.6 Heather Moor: three quarters of the Flower Forest's ground
-- (2026-09-16) — "flower forest should be much more rare and to do that I
-- want to add another biome that will take up about 75% of what flower
-- forest does now".
--
-- Open heath on the wet side of the mild rings: a purple carpet of heather
-- over peaty turf, gorse bushes in yellow-green clumps, bracken in patches,
-- granite boulders and the odd tor, bare black peat hags in long strips
-- where it has been cut, and wind-bent hawthorns alone on the rises. The
-- gullies' floors are wet and their deepest reaches hold dark water.
--
-- PLACEMENT. The Flower Forest's province side, "b", from the line to a
-- split of 0.383 of the province noise; the Flower Forest keeps the rest
-- past it. Measured over 40,000 samples: 0.383 is the noise's 87.5th
-- percentile, so the forest keeps an eighth of the wet side's ground where
-- it had half — a quarter of what it had. (A span's sixth entry, the
-- upper split, since this biome.)
--
-- A dressing biome: the mild rings' programs are at 999 of 1,024 and take
-- no more terms. It stands on the wet side's gullies and bluffs and the
-- Flower Forest's knolls, which are not province-gated. New nodes:
-- `heather`, `gorse`. Bracken is the woodland's fern; peat is `black_mud`.

local blocks = tdw.blocks
local shape = tdw.shape
local schem = tdw.schem
local n = shape.node
local ID = "heather_moor"
local WATER = "tiamat_default_world:water"

local HEATHER_FREQ, HEATHER_MIN = 1 / 14, -0.18          -- the heather: most of the ground
local HEATHER_THIN_FREQ, HEATHER_THIN_MIN = 1.4, -0.25   -- broken up at the cell's scale
local BRACKEN_FREQ, BRACKEN_MIN = 1 / 50, 0.16           -- bracken patches, where the heather is not
local GRASS_FREQ, GRASS_MIN = 1.5, 0.30
-- The peat hags: bare black peat, a fifth of the field (19%, measured
-- over 6 km; the old field's was 20%). Until 2026-09-16
-- one octave drawn out five times along x, which laid ruler-straight bands
-- two hundred blocks long across the moor ("the weird geometric mud
-- stain"); now two octaves drawn out twice, with a ragged edge.
local PEAT_FREQ, PEAT_MIN = 1 / 40, 0.30
local PEAT_STRETCH = { x = 2 }
local PEAT_RAG_FREQ, PEAT_RAG_AMP = 1 / 7, 0.25          -- the hags' edges torn up at a few blocks
local STONE_FREQ, STONE_MIN = 1 / 15, 0.40               -- moss-grown granite in the turf
local GULLY_WET, BROOK_AT = 0.45, 0.76                   -- the gully depth that is wet ground, and that holds water
local GORSE_FREQ, GORSE_MIN = 1 / 60, 0.05
local GORSE_CELL, GORSE_SQUARES = 6, 0.35
local TOR_CELL, TOR_SQUARES = 60, 0.25
local BOULDER_CELL, BOULDER_SQUARES = 20, 0.25
local THORN_CELL, THORN_SQUARES = 48, 0.30

tdw.biomes[ID].ring_mode = "temperate"
tdw.biomes[ID].lazy = true
tdw.biomes[ID].soil = blocks.black_mud

-- ------------------------------------------------------------ the structures

local BLIND = { blind = true }
local ROUGH = { rough = 0.35, blind = true }
local function rng_for(name)
    return game.rng_stream({ x = 0, y = 0, z = 0, seed = 0 }, "heather_template:" .. name)
end
local PRIORITY = { [blocks.gorse] = 1, [blocks.granite] = 1, [blocks.oak_log] = 1 }

-- A gorse bush: one or two rounded clumps, a block or two tall.
local function gorse(rng)
    schem.record_begin()
    local r = 0.9 + rng:below(3) * 0.3
    schem.push_ellipsoid(blocks.gorse, 0.5, 0.5, 0.5, r, 0.6 + rng:below(3) * 0.25, r * 0.9, ROUGH)
    if rng:below(2) == 0 then
        local d = schem.DIR16[rng:below(16) + 1]
        schem.push_ellipsoid(blocks.gorse, 0.5 + d[1] * r, 0.3, 0.5 + d[2] * r, r * 0.7, 0.5, r * 0.7, ROUGH)
    end
    return schem.record_schematic(PRIORITY)
end
-- A tor: a stack of weathered granite slabs, four to seven blocks.
local function tor(rng)
    schem.record_begin()
    local y = -0.5
    local w = 2.4 + rng:below(3) * 0.4
    for _ = 1, 3 + rng:below(3) do
        local h = 0.7 + rng:below(3) * 0.2
        schem.push_ellipsoid(blocks.granite, 0.5 + (rng:below(3) - 1) * 0.3, y + h, 0.5 + (rng:below(3) - 1) * 0.3, w, h, w * 0.85, { rough = 0.2, blind = true })
        y = y + h * 1.7
        w = w * 0.8
    end
    return schem.record_schematic(PRIORITY)
end
-- A boulder with moss on it.
local function boulder(rng)
    schem.record_begin()
    local r = 0.9 + rng:below(4) * 0.3
    schem.push_ellipsoid(blocks.granite, 0.5, r * 0.25, 0.5, r, r * 0.7, r * 0.85, ROUGH)
    schem.push_ellipsoid(blocks.moss, 0.5, r * 0.8, 0.5, r * 0.6, r * 0.25, r * 0.55, { rough = 0.5, blind = true })
    return schem.record_schematic(PRIORITY)
end
-- A hawthorn bent by the wind: a short crooked trunk leaning downwind and a
-- flat, one-sided crown.
local function thorn(rng)
    schem.record_begin()
    local tall = 3 + rng:below(3)
    local d = schem.DIR16[rng:below(16) + 1]
    local lean = 1.2 + rng:below(3) * 0.4
    local trunk = { { 0.5, -1.2, 0.5, 0.35 }, { 0.5 + d[1] * lean * 0.4, tall * 0.6, 0.5 + d[2] * lean * 0.4, 0.26 },
        { 0.5 + d[1] * lean, tall, 0.5 + d[2] * lean, 0.18 } }
    schem.push_path(blocks.oak_log, trunk, BLIND)
    schem.push_ellipsoid(blocks.oak_leaves, 0.5 + d[1] * (lean + 0.6), tall + 0.3, 0.5 + d[2] * (lean + 0.6), 2.0, 0.9, 2.0, ROUGH)
    schem.push_ellipsoid(blocks.oak_leaves, 0.5 + d[1] * lean * 0.3, tall * 0.8, 0.5 + d[2] * lean * 0.3, 1.2, 0.7, 1.2, ROUGH)
    return schem.record_schematic(PRIORITY)
end

local BUILT = nil
local function structures()
    if BUILT then
        return BUILT
    end
    local out = { gorse = {}, tors = {}, boulders = {}, thorns = {} }
    if game.schematic_shapes then
        for i = 1, 6 do out.gorse[i] = gorse(rng_for("gorse:" .. i)) end
        for i = 1, 3 do out.tors[i] = tor(rng_for("tor:" .. i)) end
        for i = 1, 4 do out.boulders[i] = boulder(rng_for("boulder:" .. i)) end
        for i = 1, 4 do out.thorns[i] = thorn(rng_for("thorn:" .. i)) end
    end
    BUILT = out
    return out
end

-- ------------------------------------------------------------ the fills

-- Where the peat hags are: positive on bare peat.
function tdw.heather_peat(min)
    return n.sub(n.add(n.noise("hm_peat", PEAT_FREQ, 2, 1.0, PEAT_STRETCH),
        n.noise("hm_peat_rag", PEAT_RAG_FREQ, 1, PEAT_RAG_AMP)), n.const(min or PEAT_MIN))
end

tdw.build_biome(ID, function(ctx)
    local function masked(field)
        local mask = tdw.biome_mask(n, ID)
        field = mask and n.min(field, mask) or field
        return shape.sea_exclude and shape.sea_exclude(field, 20.0) or field
    end
    local function off_river(field)
        return shape.river_exclude and shape.river_exclude(field, (shape.RIVER_BAR or 0) + 4) or field
    end
    local function step(field)
        return n.clamp(n.mul(field, n.const(1e4)), 0.0, 1.0)
    end
    local function gully()
        return n.add(shape.gully_floor(), n.const(0.6))
    end
    local peat = tdw.heather_peat
    local conditions = {
        -- 1: heath turf over peat.
        n.const(1.0),
        -- 2: a peat hag: bare black peat.
        peat(),
        -- 3: granite in the turf, moss-grown.
        n.sub(n.noise("hm_stone", STONE_FREQ, 2, 1.0), n.const(STONE_MIN)),
        -- 4: a gully's wet floor: mud.
        n.sub(gully(), n.const(GULLY_WET)),
        -- 5: the brook's bed: gravel.
        n.sub(gully(), n.const(BROOK_AT - 0.08)),
    }
    local code = n.const(0.0)
    for k, condition in ipairs(conditions) do
        code = n.max(code, n.mul(step(condition), n.const(k)))
    end
    code = n.mul(code, step(masked(n.const(1.0))))
    local depth = shape.compile("biome.heather.depth", shape.terrain(false))
    local codes = shape.compile("biome.heather.codes", code)
    local km = 0.001
    local entries = {
        { code = 1, to = shape.SKIN_TOP, material = blocks.grass },
        { code = 1, from = shape.SKIN_TOP, to = 5 * km, material = blocks.black_mud },
        { code = 2, to = 4 * km, material = blocks.black_mud },
        { code = 3, to = 1 * km, material = blocks.moss },
        { code = 3, from = 1 * km, to = 4 * km, material = blocks.granite },
        { code = 4, to = 2 * km, material = blocks.mud },
        { code = 4, from = 2 * km, to = 5 * km, material = blocks.black_mud },
        { code = 5, to = 2 * km, material = blocks.gravel },
        { code = 5, from = 2 * km, to = 5 * km, material = blocks.black_mud },
    }
    -- Off the peat, the stones and the wet: what the covers stand on.
    local function heath(field)
        field = n.min(field, n.sub(n.const(0.0), peat()))
        field = n.min(field, n.sub(n.const(GULLY_WET - 0.05), gully()))
        return masked(off_river(field))
    end
    local function heather_n()
        return n.noise("hm_heather", HEATHER_FREQ, 2, 1.0)
    end
    local heather = shape.compile("biome.heather.heather", heath(n.min(n.sub(heather_n(), n.const(HEATHER_MIN)),
        n.sub(n.noise("hm_heather_thin", HEATHER_THIN_FREQ, 1, 1.0), n.const(HEATHER_THIN_MIN)))))
    local bracken = shape.compile("biome.heather.bracken", heath(n.min(n.sub(n.const(HEATHER_MIN), heather_n()),
        n.sub(n.noise("hm_bracken", BRACKEN_FREQ, 2, 1.0), n.const(BRACKEN_MIN)))))
    local grass = shape.compile("biome.heather.grass", heath(n.min(n.sub(n.const(HEATHER_MIN - 0.02), heather_n()),
        n.sub(n.noise("hm_grass", GRASS_FREQ, 1, 1.0), n.const(GRASS_MIN)))))
    local fills = {
        { layers = true, depth = depth, code = codes, entries = entries, body = true },
        { cover = blocks.heather, cells = 2, take = heather },
        { cover = blocks.fern, cells = 3, take = bracken },
        { cover = blocks.tall_grass, cells = 2, take = grass },
    }
    if game.schematic_shapes then
        local built = structures()
        local function scatter(name, list, field, cell, chance, salt, above)
            fills[#fills + 1] = { scatter = true, depth = depth, schematics = list, cell = cell, chance = chance,
                salt = salt, sink = 1, above = above,
                stand = shape.compile("biome.heather.stand_" .. name, masked(off_river(n.min(field, n.sub(n.const(0.3), gully()))))) }
        end
        local dry = n.sub(n.const(0.0), peat())
        scatter("gorse", built.gorse, n.min(dry, n.sub(n.noise("hm_gorse", GORSE_FREQ, 2, 1.0), n.const(GORSE_MIN))), GORSE_CELL, GORSE_SQUARES, 261, 0.004)
        scatter("tor", built.tors, dry, TOR_CELL, TOR_SQUARES, 262, 0.010)
        scatter("boulder", built.boulders, dry, BOULDER_CELL, BOULDER_SQUARES, 263, 0.004)
        scatter("thorn", built.thorns, n.min(dry, n.sub(n.const(GORSE_MIN), n.noise("hm_gorse", GORSE_FREQ, 2, 1.0))), THORN_CELL, THORN_SQUARES, 264, 0.008)
    end
    -- Dark water in the gullies' deepest reaches, as the Flower Forest's
    -- brooks: most of the gully's depth under the ground beside it.
    --
    -- **`within` reads no height** (2026-09-23): the Flower Forest's
    -- write-up (flower_forest.lua) is this fill's too, term for term —
    -- same spans, same wet half, and the gully term dropped for the same
    -- exact reason: the level is the ground plus GULLY_DEPTH * (gully -
    -- BROOK_AT), so the room under it IS the test the term restated on
    -- the plane y = 0.5, where an unstretched noise is a different set of
    -- lines (engine ask 35; the guard is in hooks.lua). Only the province
    -- differs: the moor is side "b" from the line to 0.383, the forest
    -- past it, so the two brooks meet at smooth lines a flat-stretched
    -- hair wide and their levels differ by a twentieth of a block. The
    -- river and coast terms are the forest's too: a river trough and the
    -- coast's lifted floor carry no gully for the level to restore (up
    -- to GULLY_DEPTH * (1 - BROOK_AT), 0.6 blocks, stood proud there),
    -- so the course is kept out to the rim and a "_shore" program stops
    -- the brooks over the floor clamp's whole reach (PLAIN_W + FADE).
    local level = shape.gully_water_level(BROOK_AT)
    local within
    if tdw.config.everywhere then
        within = n.const(1.0)
    else
        local SHARE = shape.RING_WOBBLE_SHARE
        local function flat_band(lo, hi)
            local mid, half = (lo + hi) / 2, (hi - lo) / 2
            return n.sub(n.const(half), n.abs(n.sub(shape.sub.u(), n.const(mid))))
        end
        local t, sh = tdw.layers.ring_by_id.temperate, tdw.layers.ring_by_id.shore
        within = n.max(flat_band(t.u[1] / (1.0 - SHARE), t.u[2] / (1.0 - SHARE)),
            flat_band(sh.u[1] / (1.0 + SHARE), sh.u[2] / (1.0 + SHARE)))
        within = n.min(within, n.sub(shape.humidity(), n.const(shape.HUMIDITY_SPLIT)))
        within = n.min(within, n.min(shape.province_mask("b"), shape.province_mask("a", 0.383)))
    end
    if shape.river_exclude then
        within = shape.river_exclude(within, (shape.RIVER_RIM or 150) + 4)
    end
    if shape.sea_exclude then
        local inset = 20.0
        if tdw.seas and tdw.seas.on() and shape.terrain_mode and shape.terrain_mode:find("_shore", 1, true) then
            inset = (tdw.seas.PLAIN_W or 130.0) + (tdw.seas.FADE or 900.0)
        end
        within = shape.sea_exclude(within, inset)
    end
    fills[#fills + 1] = {
        fluid = WATER,
        level = shape.compile("biome.heather.brook_level", level),
        within = shape.compile("biome.heather.brook_within", within),
    }
    return fills
end)
