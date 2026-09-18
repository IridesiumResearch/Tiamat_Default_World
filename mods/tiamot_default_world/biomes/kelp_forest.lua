-- SPDX-FileCopyrightText: Iridesium
-- SPDX-License-Identifier: GPL-3.0-only
--
-- 3.7 Kelp Forest: the third sea lane's water (2026-09-16), 41.1 to 48.5 km
-- off the Long Shore — "we prob need at least 4 more ocean biomes".
--
-- The cold shelf under a canopy: kelp standing in dense groves from the
-- terrace's shallows to the ledge's foot, the tallest reaching from forty
-- blocks down to just under the surface; a floor of sand between reefs of
-- moss-grown rock; urchin barrens of bare gravel where the groves open;
-- boulders fallen off the ledge. Light comes down through the gaps.
--
-- Where: the lane's sea side, from the coastline to the shelf's end, on
-- the TRUE radius (the lanes are placed by it, not by the wobbled one the
-- rings use). The Coastal Cliffs keep the land side and their face
-- (`shape.off_kelp`), as they do along the reef's lagoon. Its ground is the
-- coast's shelf, unchanged. No new nodes.

local blocks = tdw.blocks
local shape = tdw.shape
local schem = tdw.schem
local seas = tdw.seas
local n = shape.node
local ID = "kelp_forest"

local R2 = shape.R_DISC * shape.R_DISC
local KELP_U = { 0.475, 0.694 }                          -- the lane (0.485 to 0.676) and its shores; the fourth lane's water starts past 0.694
local FADE_U = 0.004
local ROCK_FREQ, ROCK_MIN = 1 / 35, 0.05                 -- moss-grown rock reefs
local BARREN_FREQ, BARREN_MIN = 1 / 70, 0.28             -- urchin barrens: bare gravel
local GROVE_FREQ, GROVE_MIN = 1 / 80, -0.12              -- the groves: most of the floor
local KELP_CELL = 3
local BANDS = {                                          -- depth under the sea, km, and the kelp's height, blocks
    { 0.005, 0.012, 3, 6, 0.70 },
    { 0.012, 0.024, 9, 16, 0.70 },
    { 0.024, 0.048, 20, 34, 0.65 },
}
local BOULDER_CELL, BOULDER_SQUARES = 18, 0.25

-- The lane's band on the true radius, 0 to 1.
local function band()
    local u = n.mul(n.add(n.mul(n.X(), n.X()), n.mul(n.Z(), n.Z())), n.const(1e-6 / R2))
    local mid, half = (KELP_U[1] + KELP_U[2]) / 2, (KELP_U[2] - KELP_U[1]) / 2
    return n.clamp(n.mul(n.sub(n.const(half), n.abs(n.sub(u, n.const(mid)))), n.const(1.0 / FADE_U)), 0.0, 1.0)
end
-- For the coast: positive where the kelp's water is not.
function shape.off_kelp()
    return n.max(n.sub(n.const(0.5), band()), n.mul(seas.d_map(), n.const(-1.0)))
end
tdw.kelp_u = { KELP_U[1], KELP_U[2] }
function tdw.kelp_zone(x, z)
    local only = tdw.config.everywhere
    if only then
        return only == ID and ID or nil
    end
    local u = (x * x + z * z) * 1e-6 / R2
    return (u >= KELP_U[1] and u <= KELP_U[2]) and ID or nil
end

tdw.biomes[ID].ring_mode = "temperate"
tdw.biomes[ID].lazy = true
tdw.biomes[ID].soil = blocks.sand
tdw.biomes[ID].present = function(pos)
    if seas.class(pos) ~= "shore" then
        return false
    end
    local x, z = pos.x * 16 + 8, pos.z * 16 + 8
    local u = (x * x + z * z) * 1e-6 / R2
    return u >= KELP_U[1] - 0.002 and u <= KELP_U[2] + 0.002
end
tdw.biomes[ID].locate = function(px, pz, seed)
    return seas.locate(px, pz, seed, 40.0, 110.0, KELP_U[1], KELP_U[2])
end

-- ------------------------------------------------------------ the structures

local CENTRE_COLUMN = (1 << 4) | (1 << 13) | (1 << 22)
local function kelp(tall)
    local list = {}
    for dy = 0, tall - 1 do
        list[#list + 1] = { 0, dy, 0, blocks.kelp, CENTRE_COLUMN }
    end
    return game.schematic(list)
end
local function rng_for(name)
    return game.rng_stream({ x = 0, y = 0, z = 0, seed = 0 }, "kelp_template:" .. name)
end
local PRIORITY = { [blocks.stone] = 1, [blocks.ocean_moss] = 1 }
local function boulder(rng)
    schem.record_begin()
    local r = 1.2 + rng:below(4) * 0.4
    schem.push_ellipsoid(blocks.stone, 0.5, r * 0.3, 0.5, r, r * 0.75, r * 0.9, { rough = 0.35, blind = true })
    schem.push_ellipsoid(blocks.ocean_moss, 0.5, r * 0.9, 0.5, r * 0.7, r * 0.3, r * 0.7, { rough = 0.5, blind = true })
    return schem.record_schematic(PRIORITY)
end

local BUILT = nil
local function structures()
    if BUILT then
        return BUILT
    end
    local out = { bands = {}, boulders = {} }
    if game.schematic and game.schematic_shapes then
        for b, spec in ipairs(BANDS) do
            out.bands[b] = {}
            for tall = spec[3], spec[4] do
                out.bands[b][#out.bands[b] + 1] = kelp(tall)
            end
        end
        for i = 1, 4 do out.boulders[i] = boulder(rng_for("boulder:" .. i)) end
    end
    BUILT = out
    return out
end

-- ------------------------------------------------------------ the fills

tdw.build_biome(ID, function(ctx)
    local function ys()
        return n.mul(n.sub(n.Y(), n.const(shape.Y0)), n.const(shape.SCALE))
    end
    local function over_sea()
        return n.sub(ys(), seas.level())
    end
    local function out()
        return n.clamp(seas.d_map(), 0.0, seas.DIST_FAR)
    end
    local function zone()
        local at_sea = n.min(seas.d_map(), n.sub(n.const(seas.SHELF_END + 20.0), out()))
        return n.min(at_sea, n.sub(band(), n.const(0.5)))
    end
    local function masked(field)
        return n.min(field, zone())
    end
    local function step(field)
        return n.clamp(n.mul(field, n.const(1e4)), 0.0, 1.0)
    end
    local function rock()
        return n.sub(n.noise("kf_rock", ROCK_FREQ, 2, 1.0), n.const(ROCK_MIN))
    end
    local conditions = {
        -- 1: sand.
        n.const(1.0),
        -- 2: a rock reef, moss-grown.
        rock(),
        -- 3: an urchin barren: bare gravel.
        n.sub(n.noise("kf_barren", BARREN_FREQ, 2, 1.0), n.const(BARREN_MIN)),
    }
    local code = n.const(0.0)
    for k, condition in ipairs(conditions) do
        code = n.max(code, n.mul(step(condition), n.const(k)))
    end
    code = n.mul(code, step(zone()))
    local depth = shape.compile("biome.kelp.depth", shape.terrain(false))
    local codes = shape.compile("biome.kelp.codes", code)
    local km = 0.001
    local entries = {
        { code = 1, to = 4 * km, material = blocks.sand },
        { code = 2, to = 1 * km, material = blocks.ocean_moss },
        { code = 2, from = 1 * km, to = 12 * km, material = blocks.stone },
        { code = 3, to = 3 * km, material = blocks.gravel },
    }
    local fills = {
        { layers = true, depth = depth, code = codes, entries = entries },
    }
    if game.schematic and game.schematic_shapes then
        local built = structures()
        local grove = n.min(n.sub(n.noise("kf_grove", GROVE_FREQ, 2, 1.0), n.const(GROVE_MIN)),
            n.sub(n.const(BARREN_MIN), n.noise("kf_barren", BARREN_FREQ, 2, 1.0)))
        for b, spec in ipairs(BANDS) do
            local deep_enough = n.min(n.sub(n.const(-spec[1]), over_sea()), n.add(over_sea(), n.const(spec[2])))
            fills[#fills + 1] = { scatter = true, depth = depth, schematics = built.bands[b], cell = KELP_CELL, chance = spec[5],
                salt = 270 + b, sink = 0, above = spec[4] * 0.001 + 0.002,
                stand = shape.compile("biome.kelp.stand_" .. b, masked(n.min(grove, deep_enough))) }
        end
        fills[#fills + 1] = { scatter = true, depth = depth, schematics = built.boulders, cell = BOULDER_CELL, chance = BOULDER_SQUARES,
            salt = 274, sink = 1, above = 0.004,
            stand = shape.compile("biome.kelp.stand_boulder", masked(n.min(n.sub(n.const(-0.004), over_sea()), rock()))) }
    end
    return fills
end)
