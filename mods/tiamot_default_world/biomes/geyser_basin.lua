-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- 3.4 Geyser Basin: the Ember Ridge's other province, wet side
-- (2026-09-16).
--
-- A broad shallow basin floored with pale sinter, the crust hot water lays
-- down as it cools: stepped in low terrace dams round steaming pools, with
-- orange and ochre microbial mats streaming down the runoff, grey mud pots
-- bubbling in patches, low sinter mounds, and geyser cones — a squat
-- sinter chimney with a sulfur throat, which puffs steam by the same random
-- tick as the Foothills' fissures. Dead snags at the basin's edges.
--
-- Its terms (`shape.geyser_terms`) stand in the "ember" programs in place
-- of the Foothills' where the province is "b", on the wet side (shape.lua).
-- The pools are water by the terraced fluid fill. New nodes: `sinter`,
-- `thermal_mat`.

local blocks = tdw.blocks
local shape = tdw.shape
local schem = tdw.schem
local n = shape.node
local ID = "geyser_basin"
local WATER = "tiamot_default_world:water"

local BASIN_FREQ, BASIN_D = 1 / 500, 0.005               -- the basin's floor, five blocks down where the noise is high
local UNDULATE_FREQ, UNDULATE_AMP = 1 / 200, 0.003
local DAM_FREQ, DAM_W, DAM_H = 1 / 16, 1.3, 0.0012       -- terrace dams: a block high along a fine contour
local POOL_FREQ, POOL_MIN, POOL_EDGE, POOL_D = 1 / 45, 0.22, 9.0, 0.0025
local POOL_FILL = 0.0015                                 -- km: the water a block and a half over a pool's floor
local MOUND_FREQ, MOUND_MIN, MOUND_EDGE, MOUND_H = 1 / 120, 0.30, 8.0, 0.004
local MAT_HALO = { 0.05, 0.55 }                          -- the pool weight band that is a pool's halo of mats
local MUD_FREQ, MUD_MIN = 1 / 60, 0.30
local SULFUR_FREQ, SULFUR_MIN = 1 / 7, 0.40
local CONE_CELL, CONE_SQUARES = 30, 0.40
local MUDPOT_CELL, MUDPOT_SQUARES = 16, 0.35
local SNAG_CELL, SNAG_SQUARES = 24, 0.25

-- ------------------------------------------------------------ the ground

local function clamp01(field, lo, edge)
    return n.clamp(n.mul(n.sub(field, n.const(lo)), n.const(edge)), 0.0, 1.0)
end
local function basin_w()
    return n.clamp(n.mul(n.add(n.noise("gb_basin", BASIN_FREQ, 2, 1.0), n.const(0.1)), n.const(4.0)), 0.0, 1.0)
end
local function pool_w()
    return clamp01(n.noise("gb_pool", POOL_FREQ, 1, 1.0), POOL_MIN, POOL_EDGE)
end
local function dam_w()
    return n.clamp(n.add(n.mul(n.contour("gb_dam", DAM_FREQ, 1), n.const(-1.0 / DAM_W)), n.const(1.0)), 0.0, 1.0)
end
local function mound_w()
    return clamp01(n.noise("gb_mound", MOUND_FREQ, 1, 1.0), MOUND_MIN, MOUND_EDGE)
end
local function undulate()
    return n.noise("gb_undulate", UNDULATE_FREQ, 1, UNDULATE_AMP)
end

-- The Basin's terms, km: the floor, the pools sunk in it, the dams and
-- mounds standing on it.
function shape.geyser_terms()
    local acc = n.sub(undulate(), n.mul(basin_w(), n.const(BASIN_D)))
    acc = n.sub(acc, n.mul(pool_w(), n.const(POOL_D)))
    acc = n.add(acc, n.mul(n.mul(dam_w(), n.add(n.mul(pool_w(), n.const(-1.0)), n.const(1.0))), n.const(DAM_H)))
    return n.add(acc, n.mul(mound_w(), n.const(MOUND_H)))
end

tdw.biomes[ID].ring_mode = "ember"
tdw.biomes[ID].lazy = true
tdw.biomes[ID].soil = blocks.sinter

-- ------------------------------------------------------------ the structures

local ROUGH = { rough = 0.3, blind = true }
local function rng_for(name)
    return game.rng_stream({ x = 0, y = 0, z = 0, seed = 0 }, "geyser_template:" .. name)
end
local PRIORITY = { [blocks.sinter] = 1, [blocks.sulfur] = 1, [blocks.mud] = 1 }

-- A geyser cone: a squat sinter chimney two to four blocks, a sulfur throat
-- at its top that the random tick puffs steam from.
local function cone(rng)
    schem.record_begin()
    local tall = 2 + rng:below(3)
    local r = 1.6 + rng:below(3) * 0.3
    schem.push_path(blocks.sinter, { { 0.5, -1.0, 0.5, r }, { 0.5, tall * 0.6, 0.5, r * 0.6 }, { 0.5, tall, 0.5, 0.7 } }, ROUGH)
    schem.push_ellipsoid(blocks.sulfur, 0.5, tall - 0.2, 0.5, 0.45, 0.5, 0.45, { blind = true })
    return schem.record_schematic(PRIORITY)
end
-- A mud pot's rim: a low ring of grey mud.
local function mudpot(rng)
    schem.record_begin()
    local r = 1.3 + rng:below(3) * 0.3
    schem.push_ellipsoid(blocks.mud, 0.5, -0.3, 0.5, r, 0.7, r, ROUGH)
    return schem.record_schematic(PRIORITY)
end
-- A snag killed by the heat, white at the foot.
local function snag(rng)
    schem.record_begin()
    local tall = 3 + rng:below(4)
    local d = schem.DIR16[rng:below(16) + 1]
    schem.push_path(blocks.dead_wood, { { 0.5, -1.5, 0.5, 0.35 }, { 0.5 + d[1] * 0.5, tall, 0.5 + d[2] * 0.5, 0.15 } }, { blind = true })
    schem.push_ellipsoid(blocks.sinter, 0.5, 0.0, 0.5, 0.9, 0.4, 0.9, ROUGH)
    return schem.record_schematic(PRIORITY)
end

local BUILT = nil
local function structures()
    if BUILT then
        return BUILT
    end
    local out = { cones = {}, mudpots = {}, snags = {} }
    if game.schematic_shapes then
        for i = 1, 5 do out.cones[i] = cone(rng_for("cone:" .. i)) end
        for i = 1, 3 do out.mudpots[i] = mudpot(rng_for("mudpot:" .. i)) end
        for i = 1, 3 do out.snags[i] = snag(rng_for("snag:" .. i)) end
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
    local function step(field)
        return n.clamp(n.mul(field, n.const(1e4)), 0.0, 1.0)
    end
    local function halo()
        return n.min(n.sub(pool_w(), n.const(MAT_HALO[1])), n.sub(n.const(MAT_HALO[2]), pool_w()))
    end
    local conditions = {
        -- 1: sinter.
        n.const(1.0),
        -- 2: ash at the basin's edges.
        n.sub(n.const(0.25), basin_w()),
        -- 3: thermal mats: a pool's halo, and along the dams.
        n.max(halo(), n.min(n.sub(dam_w(), n.const(0.6)), n.sub(basin_w(), n.const(0.5)))),
        -- 4: mud pots.
        n.sub(n.noise("gb_mud", MUD_FREQ, 2, 1.0), n.const(MUD_MIN)),
        -- 5: a pool's floor: sinter again, clean.
        n.sub(pool_w(), n.const(0.6)),
        -- 6: sulfur specks in the halo, which steam.
        n.min(halo(), n.sub(n.noise("gb_sulfur", SULFUR_FREQ, 1, 1.0), n.const(SULFUR_MIN))),
    }
    local code = n.const(0.0)
    for k, condition in ipairs(conditions) do
        code = n.max(code, n.mul(step(condition), n.const(k)))
    end
    code = n.mul(code, step(masked(n.const(1.0))))
    local depth = shape.compile("biome.geyser.depth", shape.terrain(false))
    local codes = shape.compile("biome.geyser.codes", code)
    local km = 0.001
    local entries = {
        { code = 1, to = 4 * km, material = blocks.sinter },
        { code = 1, from = 4 * km, to = 6 * km, material = blocks.dark_basalt },
        { code = 2, to = 2 * km, material = blocks.volcanic_ash },
        { code = 2, from = 2 * km, to = 6 * km, material = blocks.dark_basalt },
        { code = 3, to = 1 * km, material = blocks.thermal_mat },
        { code = 3, from = 1 * km, to = 4 * km, material = blocks.sinter },
        { code = 4, to = 3 * km, material = blocks.mud },
        { code = 4, from = 3 * km, to = 6 * km, material = blocks.sinter },
        { code = 5, to = 4 * km, material = blocks.sinter },
        { code = 6, to = 1 * km, material = blocks.sulfur },
        { code = 6, from = 1 * km, to = 4 * km, material = blocks.sinter },
    }
    local fills = {
        { layers = true, depth = depth, code = codes, entries = entries, body = true },
    }
    if game.schematic_shapes then
        local built = structures()
        local function scatter(name, list, field, cell, chance, salt, above)
            fills[#fills + 1] = { scatter = true, depth = depth, schematics = list, cell = cell, chance = chance,
                salt = salt, sink = 1, above = above, stand = shape.compile("biome.geyser.stand_" .. name, masked(field)) }
        end
        local dry = n.sub(n.const(0.02), pool_w())
        scatter("cone", built.cones, n.min(dry, n.sub(basin_w(), n.const(0.4))), CONE_CELL, CONE_SQUARES, 241, 0.006)
        scatter("mudpot", built.mudpots, n.min(dry, n.sub(n.noise("gb_mud", MUD_FREQ, 2, 1.0), n.const(MUD_MIN + 0.05))), MUDPOT_CELL, MUDPOT_SQUARES, 242, 0.002)
        scatter("snag", built.snags, n.min(dry, n.sub(n.const(0.3), basin_w())), SNAG_CELL, SNAG_SQUARES, 243, 0.008)
    end
    -- The pools, last: water POOL_FILL over a pool's floor, by the terraced
    -- fluid fill. The level follows the basin's own terms at the ridge's
    -- weight; the ring's small gullies are not in it, so a pool is a block
    -- deeper or shallower than its neighbour.
    local terms = n.mul(n.sub(undulate(), n.mul(basin_w(), n.const(BASIN_D))), shape.ember_weight())
    fills[#fills + 1] = {
        fluid = WATER,
        level = shape.compile("biome.geyser.pool_level", n.add(n.mul(n.add(n.add(shape.relief_node(), shape.dome_node()), terms),
            n.const(1.0 / shape.SCALE)), n.const(shape.Y0 + (POOL_FILL - POOL_D) / shape.SCALE))),
        within = shape.compile("biome.geyser.pool_within", masked(n.sub(pool_w(), n.const(0.75)))),
    }
    return fills
end)
