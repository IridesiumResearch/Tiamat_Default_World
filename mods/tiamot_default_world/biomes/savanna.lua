-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- 3.11 Savanna: the Verdant Belt's dry half (2026-09-16) — "at least
-- another 4 for variety in the main part of the world". The Rolling
-- Grasslands had it; they keep the temperate ring's dry half and the Long
-- Shore's.
--
-- Golden grass to the knee over red-brown earth, flat-topped acacias
-- standing apart with their crowns spread like tables, termite mounds
-- rising out of the grass, bare patches of packed earth, and kopjes — piles
-- of rounded granite boulders — here and there on the swells.
--
-- A dressing biome, on the dry side's swells. New nodes: `golden_grass`,
-- `acacia_wood`, `acacia_leaves`.

local blocks = tdw.blocks
local shape = tdw.shape
local schem = tdw.schem
local n = shape.node
local ID = "savanna"

local GRASS_FREQ, GRASS_MIN = 1.4, -0.22                 -- the golden grass: most of the ground
local GRASS_PATCH_FREQ, GRASS_PATCH_MIN = 1 / 40, -0.30
local BARE_FREQ, BARE_MIN = 1 / 30, 0.30                 -- bare packed earth
local SAND_FREQ, SAND_MIN = 1 / 55, 0.36
local ACACIA_CELL, ACACIA_SQUARES = 28, 0.45
local MOUND_CELL, MOUND_SQUARES = 22, 0.35
local KOPJE_CELL, KOPJE_SQUARES = 64, 0.20
local SHRUB_CELL, SHRUB_SQUARES = 12, 0.25

tdw.biomes[ID].ring_mode = "belt"
tdw.biomes[ID].lazy = true
tdw.biomes[ID].soil = blocks.dirt

-- ------------------------------------------------------------ the structures

local BLIND = { blind = true }
local function rng_for(name)
    return game.rng_stream({ x = 0, y = 0, z = 0, seed = 0 }, "savanna_template:" .. name)
end
local PRIORITY = { [blocks.acacia_wood] = 1, [blocks.packed_dirt] = 1, [blocks.granite] = 1 }

-- An acacia: a trunk that forks low into two or three limbs leaning out,
-- each ending under a flat, wide pad of leaves, the pads together a table.
local function acacia(rng)
    schem.record_begin()
    local fork = 2.5 + rng:below(3) * 0.5
    local tall = 7 + rng:below(4)
    schem.push_path(blocks.acacia_wood, { { 0.5, -1.2, 0.5, 0.42 }, { 0.5, fork, 0.5, 0.34 } }, BLIND)
    local limbs = 2 + rng:below(2)
    local first = rng:below(16)
    for i = 0, limbs - 1 do
        local d = schem.DIR16[(first + i * 16 // limbs + rng:below(2)) % 16 + 1]
        local reach = 2.2 + rng:below(3) * 0.5
        local tip = { 0.5 + d[1] * reach, tall - rng:below(2), 0.5 + d[2] * reach }
        schem.push_path(blocks.acacia_wood, { { 0.5, fork, 0.5, 0.26 }, { 0.5 + d[1] * reach * 0.5, fork + (tall - fork) * 0.6, 0.5 + d[2] * reach * 0.5, 0.2 },
            { tip[1], tip[2], tip[3], 0.14 } }, BLIND)
        schem.push_ellipsoid(blocks.acacia_leaves, tip[1], tip[2] + 0.5, tip[3], 2.8 + rng:below(3) * 0.4, 0.7, 2.8 + rng:below(3) * 0.4, { rough = 0.3, blind = true })
    end
    return schem.record_schematic(PRIORITY)
end
-- A termite mound: a lumpy spire of packed earth, three to six blocks.
local function mound(rng)
    schem.record_begin()
    local tall = 3 + rng:below(4)
    schem.push_path(blocks.packed_dirt, { { 0.5, -1.0, 0.5, 1.4 + rng:below(3) * 0.2 }, { 0.5, tall * 0.5, 0.5, 0.9 }, { 0.5 + (rng:below(3) - 1) * 0.3, tall, 0.5, 0.35 } }, { rough = 0.4, blind = true })
    if rng:below(2) == 0 then
        local d = schem.DIR16[rng:below(16) + 1]
        schem.push_path(blocks.packed_dirt, { { 0.5 + d[1], -0.5, 0.5 + d[2], 0.7 }, { 0.5 + d[1] * 1.2, tall * 0.5, 0.5 + d[2] * 1.2, 0.3 } }, { rough = 0.4, blind = true })
    end
    return schem.record_schematic(PRIORITY)
end
-- A kopje: a heap of rounded granite boulders.
local function kopje(rng)
    schem.record_begin()
    for _ = 1, 4 + rng:below(4) do
        local d = schem.DIR16[rng:below(16) + 1]
        local off = rng:below(4) * 0.8
        local r = 1.2 + rng:below(4) * 0.4
        schem.push_ellipsoid(blocks.granite, 0.5 + d[1] * off, r * 0.5 + rng:below(3) * 0.6, 0.5 + d[2] * off, r, r * 0.85, r, { rough = 0.2, blind = true })
    end
    return schem.record_schematic(PRIORITY)
end
-- A thorn shrub: a low tangle of acacia wood with a few leaves.
local function shrub(rng)
    schem.record_begin()
    for _ = 1, 3 do
        local d = schem.DIR16[rng:below(16) + 1]
        schem.push_path(blocks.acacia_wood, { { 0.5, -0.5, 0.5, 0.12 }, { 0.5 + d[1] * 1.1, 1.2 + rng:below(2) * 0.4, 0.5 + d[2] * 1.1, 0.08 } }, BLIND)
    end
    schem.push_ellipsoid(blocks.acacia_leaves, 0.5, 1.3, 0.5, 1.1, 0.5, 1.1, { rough = 0.5, blind = true })
    return schem.record_schematic(PRIORITY)
end

local BUILT = nil
local function structures()
    if BUILT then
        return BUILT
    end
    local out = { acacias = {}, mounds = {}, kopjes = {}, shrubs = {} }
    if game.schematic_shapes then
        for i = 1, 8 do out.acacias[i] = acacia(rng_for("acacia:" .. i)) end
        for i = 1, 5 do out.mounds[i] = mound(rng_for("mound:" .. i)) end
        for i = 1, 3 do out.kopjes[i] = kopje(rng_for("kopje:" .. i)) end
        for i = 1, 4 do out.shrubs[i] = shrub(rng_for("shrub:" .. i)) end
    end
    BUILT = out
    return out
end

-- ------------------------------------------------------------ the fills

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
    local function bare()
        return n.sub(n.noise("sv_bare", BARE_FREQ, 2, 1.0), n.const(BARE_MIN))
    end
    local conditions = {
        -- 1: red-brown earth.
        n.const(1.0),
        -- 2: bare packed earth.
        bare(),
        -- 3: pale sand in the hollows.
        n.sub(n.noise("sv_sand", SAND_FREQ, 2, 1.0), n.const(SAND_MIN)),
    }
    local code = n.const(0.0)
    for k, condition in ipairs(conditions) do
        code = n.max(code, n.mul(step(condition), n.const(k)))
    end
    code = n.mul(code, step(masked(n.const(1.0))))
    local depth = shape.compile("biome.savanna.depth", shape.terrain(false))
    local codes = shape.compile("biome.savanna.codes", code)
    local km = 0.001
    local entries = {
        { code = 1, to = 5 * km, material = blocks.dirt },
        { code = 2, to = 5 * km, material = blocks.packed_dirt },
        { code = 3, to = 3 * km, material = blocks.sand },
        { code = 3, from = 3 * km, to = 5 * km, material = blocks.dirt },
    }
    local grass = shape.compile("biome.savanna.grass", masked(off_river(n.min(n.min(n.sub(n.const(0.0), bare()),
        n.sub(n.noise("sv_grass", GRASS_FREQ, 1, 1.0), n.const(GRASS_MIN))),
        n.sub(n.noise("sv_grass_patch", GRASS_PATCH_FREQ, 2, 1.0), n.const(GRASS_PATCH_MIN))))))
    local fills = {
        { layers = true, depth = depth, code = codes, entries = entries, body = true },
        { cover = blocks.golden_grass, cells = 3, take = grass },
    }
    if game.schematic_shapes then
        local built = structures()
        local function scatter(name, list, field, cell, chance, salt, above)
            fills[#fills + 1] = { scatter = true, depth = depth, schematics = list, cell = cell, chance = chance,
                salt = salt, sink = 1, above = above, stand = shape.compile("biome.savanna.stand_" .. name, masked(off_river(field))) }
        end
        scatter("acacia", built.acacias, n.const(1.0), ACACIA_CELL, ACACIA_SQUARES, 301, 0.012)
        scatter("mound", built.mounds, n.const(1.0), MOUND_CELL, MOUND_SQUARES, 302, 0.007)
        scatter("kopje", built.kopjes, n.const(1.0), KOPJE_CELL, KOPJE_SQUARES, 303, 0.008)
        scatter("shrub", built.shrubs, n.const(1.0), SHRUB_CELL, SHRUB_SQUARES, 304, 0.003)
    end
    return fills
end)
