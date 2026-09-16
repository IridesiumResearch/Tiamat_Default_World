-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- 3.13 Peat Fen: a quarter of the Temperate Woodlands' province in the
-- temperate ring (2026-09-16).
--
-- Flat wet ground: a carpet of sphagnum moss over black peat, open pools of
-- dark water in every low place ringed with reed beds, cotton grass on the
-- drier hummocks, and bog oaks — black, dead, thousands of years in the
-- peat — lying half sunk or standing as broken stumps.
--
-- WHERE: the Woodlands' province side "a" past a split of -0.383 of the
-- province noise (its 12.5th percentile), in the temperate ring; the
-- Redwood Stands take the same share on the Long Shore. A dressing biome:
-- the mild rings' programs are at 999. The pools are the wet side's gully
-- floors, filled wider than a brook. New node: `reeds`.

local blocks = tdw.blocks
local shape = tdw.shape
local schem = tdw.schem
local n = shape.node
local ID = "peat_fen"
local WATER = "tiamot_default_world:water"

local POOL_AT = 0.42                                    -- the gully depth the water reaches: wide, shallow pools
local REED_BAND = { 0.20, 0.46 }                        -- the gully depth band the reeds stand in
local PEAT_FREQ, PEAT_MIN = 1 / 30, 0.25
local COTTON_FREQ, COTTON_MIN = 1.4, 0.30
local REED_THIN_FREQ, REED_THIN_MIN = 1.3, -0.20
local STUMP_CELL, STUMP_SQUARES = 30, 0.30
local LOG_CELL, LOG_SQUARES = 40, 0.35

tdw.biomes[ID].ring_mode = "temperate"
tdw.biomes[ID].lazy = true
tdw.biomes[ID].soil = blocks.black_mud

-- ------------------------------------------------------------ the structures

local BLIND = { blind = true }
local function rng_for(name)
    return game.rng_stream({ x = 0, y = 0, z = 0, seed = 0 }, "fen_template:" .. name)
end
local PRIORITY = { [blocks.dead_wood] = 1 }

-- A bog oak's stump: a thick black stub two to four blocks, split.
local function stump(rng)
    schem.record_begin()
    local tall = 2 + rng:below(3)
    schem.push_path(blocks.dead_wood, { { 0.5, -1.5, 0.5, 0.9 }, { 0.5, tall, 0.5, 0.6 } }, { rough = 0.4, blind = true })
    for _ = 1, 2 do
        local d = schem.DIR16[rng:below(16) + 1]
        schem.push_path(blocks.dead_wood, { { 0.5, -0.8, 0.5, 0.35 }, { 0.5 + d[1] * 1.8, -0.6, 0.5 + d[2] * 1.8, 0.2 } }, BLIND)
    end
    return schem.record_schematic(PRIORITY)
end
-- A bog oak lying half sunk: eight to fourteen blocks of black trunk.
local function log(rng)
    schem.record_begin()
    local length = 8 + rng:below(7)
    local d = schem.DIR16[rng:below(16) + 1]
    local half = length / 2
    schem.push_path(blocks.dead_wood, { { 0.5 - d[1] * half, -0.2, 0.5 - d[2] * half, 0.8 }, { 0.5 + d[1] * half, -0.4, 0.5 + d[2] * half, 0.55 } }, BLIND)
    return schem.record_schematic(PRIORITY)
end

local BUILT = nil
local function structures()
    if BUILT then
        return BUILT
    end
    local out = { stumps = {}, logs = {} }
    if game.schematic_shapes then
        for i = 1, 4 do out.stumps[i] = stump(rng_for("stump:" .. i)) end
        for i = 1, 4 do out.logs[i] = log(rng_for("log:" .. i)) end
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
    local function gully()
        return n.add(shape.gully_floor(), n.const(0.6))
    end
    local conditions = {
        -- 1: sphagnum over peat.
        n.const(1.0),
        -- 2: bare black peat.
        n.sub(n.noise("pf_peat", PEAT_FREQ, 2, 1.0), n.const(PEAT_MIN)),
        -- 3: the pools' margins and beds: soft mud.
        n.sub(gully(), n.const(REED_BAND[1])),
    }
    local code = n.const(0.0)
    for k, condition in ipairs(conditions) do
        code = n.max(code, n.mul(step(condition), n.const(k)))
    end
    code = n.mul(code, step(masked(n.const(1.0))))
    local depth = shape.compile("biome.fen.depth", shape.terrain(false))
    local codes = shape.compile("biome.fen.codes", code)
    local km = 0.001
    local entries = {
        { code = 1, to = 1 * km, material = blocks.moss },
        { code = 1, from = 1 * km, to = 6 * km, material = blocks.black_mud },
        { code = 2, to = 6 * km, material = blocks.black_mud },
        { code = 3, to = 2 * km, material = blocks.mud },
        { code = 3, from = 2 * km, to = 6 * km, material = blocks.black_mud },
    }
    local reeds = shape.compile("biome.fen.reeds", masked(off_river(n.min(n.min(n.sub(gully(), n.const(REED_BAND[1])),
        n.sub(n.const(REED_BAND[2]), gully())), n.sub(n.noise("pf_reed_thin", REED_THIN_FREQ, 1, 1.0), n.const(REED_THIN_MIN))))))
    local cotton = shape.compile("biome.fen.cotton", masked(off_river(n.min(n.sub(n.const(REED_BAND[1] - 0.03), gully()),
        n.sub(n.noise("pf_cotton", COTTON_FREQ, 1, 1.0), n.const(COTTON_MIN))))))
    local fills = {
        { layers = true, depth = depth, code = codes, entries = entries, body = true },
        { cover = blocks.reeds, cells = 3, take = reeds },
        { cover = blocks.tall_grass, cells = 2, take = cotton },
    }
    if game.schematic_shapes then
        local built = structures()
        local function scatter(name, list, field, cell, chance, salt, above)
            fills[#fills + 1] = { scatter = true, depth = depth, schematics = list, cell = cell, chance = chance,
                salt = salt, sink = 1, above = above, stand = shape.compile("biome.fen.stand_" .. name, masked(off_river(field))) }
        end
        scatter("stump", built.stumps, n.sub(n.const(REED_BAND[1]), gully()), STUMP_CELL, STUMP_SQUARES, 321, 0.005)
        scatter("log", built.logs, n.sub(n.const(0.5), gully()), LOG_CELL, LOG_SQUARES, 322, 0.002)
    end
    -- The pools: dark water over the gullies' floors, wider than a brook.
    local level = n.add(n.mul(n.add(n.add(shape.relief_node(), shape.dome_node()),
        n.mul(shape.knoll_terms(), shape.knoll_weight())), n.const(1.0 / shape.SCALE)),
        n.const(shape.Y0 - shape.GULLY_DEPTH * POOL_AT / shape.SCALE))
    fills[#fills + 1] = {
        fluid = WATER,
        level = shape.compile("biome.fen.pool_level", level),
        within = shape.compile("biome.fen.pool_within", masked(n.sub(gully(), n.const(POOL_AT + 0.02)))),
    }
    return fills
end)
