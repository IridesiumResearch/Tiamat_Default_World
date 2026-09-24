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
-- The pools are water by the terraced fluid fill. No nodes of its own since
-- 2026-09-16: the crust is lava rock and the runoff's mats are magma.

local blocks = tdw.blocks
local shape = tdw.shape
local schem = tdw.schem
local n = shape.node
local ID = "geyser_basin"
local WATER = "tiamat_default_world:water"

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
-- The pools' weight, and **FLAT in y since 2026-09-23**: the water's
-- `within` mins this in, and a terraced fill's `within` is read on the
-- one plane y = 0.5 for the whole world (engine ask 35; the write-up is
-- at the fill below) — an unstretched noise is a DIFFERENT field down
-- there, and the water found its pools only by coincidence. Flat, the
-- sinter floor, the mats' halo, the cones' stand and the water all read
-- ONE set of pools at every height. A world generated before this has its
-- pools elsewhere on the same seed; their size, depth and count do not
-- move. The basin, dam, mound and undulation noises stay 3D: nothing but
-- the terrain reads them, and the terrain may read height.
--
-- The stretch is the POOL gates' OWN, not HUMIDITY_STRETCH: x1000 retires
-- height against fields of the humidity's scale (1/9000), and the ground
-- here stands ~28,000 blocks over the slice (Y0 is 11,000 and the dome
-- carries the rest), so after the division this 1/45 gate still read the
-- slice ~0.64 of a feature from where the terrain, the codes and the
-- stands read it — one set of pools, read from two places, and the
-- ask-35 fault reduced rather than fixed. At x1e6 the offset is under a
-- thousandth of a feature at any height the world has: flat where it
-- counts, and still comfortable in f32 (coordinates stay under 0.03
-- after the division). Shared with the Salt Pan's and the Deep Ocean's
-- gates — the `or` keeps the three declarations one table. Pools move
-- once more on existing seeds, the trade the x1000 change already
-- accepted.
shape.POOL_GATE_STRETCH = shape.POOL_GATE_STRETCH or { y = 1e6 }
local FLAT = shape.POOL_GATE_STRETCH
local function pool_w()
    return clamp01(n.noise("gb_pool", POOL_FREQ, 1, 1.0, FLAT), POOL_MIN, POOL_EDGE)
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
tdw.biomes[ID].soil = blocks.lava_rock

-- ------------------------------------------------------------ the structures

local ROUGH = { rough = 0.3, blind = true }
local function rng_for(name)
    return game.rng_stream({ x = 0, y = 0, z = 0, seed = 0 }, "geyser_template:" .. name)
end
local PRIORITY = { [blocks.lava_rock] = 1, [blocks.sulfur] = 1, [blocks.mud] = 1 }

-- A geyser cone: a squat sinter chimney two to four blocks, a sulfur throat
-- at its top that the random tick puffs steam from.
local function cone(rng)
    schem.record_begin()
    local tall = 2 + rng:below(3)
    local r = 1.6 + rng:below(3) * 0.3
    schem.push_path(blocks.lava_rock, { { 0.5, -1.0, 0.5, r }, { 0.5, tall * 0.6, 0.5, r * 0.6 }, { 0.5, tall, 0.5, 0.7 } }, ROUGH)
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
    schem.push_path(blocks.dead_log, { { 0.5, -1.5, 0.5, 0.35 }, { 0.5 + d[1] * 0.5, tall, 0.5 + d[2] * 0.5, 0.15 } }, { blind = true })
    schem.push_ellipsoid(blocks.lava_rock, 0.5, 0.0, 0.5, 0.9, 0.4, 0.9, ROUGH)
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
        { code = 1, to = 4 * km, material = blocks.lava_rock },
        { code = 1, from = 4 * km, to = 6 * km, material = blocks.dark_basalt },
        { code = 2, to = 2 * km, material = blocks.volcanic_ash },
        { code = 2, from = 2 * km, to = 6 * km, material = blocks.dark_basalt },
        { code = 3, to = 1 * km, material = blocks.magma },
        { code = 3, from = 1 * km, to = 4 * km, material = blocks.lava_rock },
        { code = 4, to = 3 * km, material = blocks.mud },
        { code = 4, from = 3 * km, to = 6 * km, material = blocks.lava_rock },
        { code = 5, to = 4 * km, material = blocks.lava_rock },
        { code = 6, to = 1 * km, material = blocks.sulfur },
        { code = 6, from = 1 * km, to = 4 * km, material = blocks.lava_rock },
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
    --
    -- **`within` rides no wobbled radius** (2026-09-23), the lava's
    -- treatment (volcanic_foothills.lua). The engine reads a terraced
    -- fill's fields on the one plane y = 0.5, and since engine ask 35 a
    -- `within` whose bounds disagree between that plane and the chunk's
    -- slab is an ERROR — the guard (hooks.lua) takes it as "no water
    -- here", and a pool chunk skipped dry. `masked()` carried the readers:
    -- the band on the WOBBLED radius and `humidity_mask`'s unstretched
    -- dither — and the pool gate itself was a 3D noise, now flat
    -- (`pool_w`, above). The band here is on the TRUE radius, and it is
    -- the WEIGHT'S support, not the catalogue ring: the ring's outer
    -- edge (u 0.1764) runs 0.012 past where the fade dies (EMBER_OUT_U),
    -- and "past the edges the weight is spent" bounds nothing there —
    -- with the weight spent the level is relief + dome less a block, but
    -- the GROUND is not relief + dome: it carries the world's ±3 blocks
    -- of detail, the temperate pair's 2.5-block gullies and the river
    -- troughs, none of which are in the level, so the weight-zero
    -- annulus ponded one to three blocks deep in every dip a flat pool
    -- spot crossed. A pool proper needs pool_w * weight > 0.4 (its cut,
    -- POOL_D * pool_w * weight, against the level's POOL_D - POOL_FILL
    -- stand-off), so nothing legitimate lies outside the fade's support
    -- [EMBER_U[1] - EMBER_BLEND_U / 2, EMBER_OUT_U] and the tighter edge
    -- costs nothing dry; each end still takes the wobble's whole reach
    -- (u_biome = u * (1 ± SHARE)). The river troughs are the one cut
    -- inside the band the level does not know: cut from the SMOOTH
    -- height, no detail and no geyser terms, so the course is kept out
    -- to the rim besides, on its own flat contour. The humidity is the
    -- smooth field at the bare split, slack for the same reason as ever:
    -- the Basin's terms fade to the Barrens' across it (shape.lua), and
    -- a half-weight cut barely reaches the level. Residue, the lava's
    -- own trade: in the wobble's fringe, or a hair past the split, a
    -- flat-pool centre crossing a hollow of the temperate pair or a cut
    -- of the Waste's can keep a film under a cell deep — the opposite
    -- fault to a dry basin.
    local terms = n.mul(n.sub(undulate(), n.mul(basin_w(), n.const(BASIN_D))), shape.ember_weight())
    local within = n.sub(pool_w(), n.const(0.75))
    if not tdw.config.everywhere then
        local SHARE = shape.RING_WOBBLE_SHARE
        local band_lo = (shape.EMBER_U[1] - shape.EMBER_BLEND_U / 2) / (1.0 + SHARE)
        local band_hi = shape.EMBER_OUT_U / (1.0 - SHARE)
        local band_mid, band_half = (band_lo + band_hi) / 2, (band_hi - band_lo) / 2
        within = n.min(within, n.sub(n.const(band_half), n.abs(n.sub(shape.sub.u(), n.const(band_mid)))))
        within = n.min(within, n.sub(shape.humidity(), n.const(shape.HUMIDITY_SPLIT)))
        within = n.min(within, shape.province_mask("b"))
    end
    if shape.river_exclude then
        within = shape.river_exclude(within, (shape.RIVER_RIM or 150) + 4)
    end
    if shape.sea_exclude then
        within = shape.sea_exclude(within, 20.0)
    end
    fills[#fills + 1] = {
        fluid = WATER,
        level = shape.compile("biome.geyser.pool_level", n.add(n.mul(n.add(n.add(shape.relief_node(), shape.dome_node()), terms),
            n.const(1.0 / shape.SCALE)), n.const(shape.Y0 + (POOL_FILL - POOL_D) / shape.SCALE))),
        within = shape.compile("biome.geyser.pool_within", within),
    }
    return fills
end)
